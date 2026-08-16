import 'dart:convert';
import 'dart:io';

import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/features/downloader/domain/entities/browser_capability.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_runtime_service.dart';
import 'package:onyxcore/features/downloader/services/deno_runtime.dart';

class DenoExtractorRuntimeService implements ExtractorRuntimeService {
  @override
  Future<ExtractorResult> execute(CustomExtractor extractor, String url, {BrowserInfo? browser, void Function(String)? onLog}) async {
    final tempDir = await Directory.systemTemp.createTemp('onyx_extractor_');
    try {
      final userScriptFile = File('${tempDir.path}/user_script.js');
      await userScriptFile.writeAsString(extractor.script);

      final wrapperScriptFile = File('${tempDir.path}/wrapper.js');
      const wrapperScript = r'''
const executablePath = Deno.env.get("PUPPETEER_EXECUTABLE_PATH");
const url = Deno.args[0];
const userScriptPath = Deno.args[1];

if (!executablePath) {
  console.error("A Chromium-based browser is required for custom extractors.");
  Deno.exit(1);
}

const browserProcess = new Deno.Command(executablePath, {
  args: [
    "--headless=new",
    "--remote-debugging-port=0",
    "--no-sandbox",
    "--disable-gpu",
    "--disable-dev-shm-usage"
  ],
  stderr: "piped"
}).spawn();

const reader = browserProcess.stderr.getReader();
const decoder = new TextDecoder();
let wsUrl = "";
while (true) {
  const {value, done} = await reader.read();
  if (value) {
    const text = decoder.decode(value);
    const match = text.match(/ws:\/\/[^\s]+/);
    if (match) {
      wsUrl = match[0];
      break;
    }
  }
  if (done) break;
}

const ws = new WebSocket(wsUrl);
await new Promise(resolve => ws.onopen = resolve);

let idCounter = 1;
const pending = new Map();

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  if (pending.has(msg.id)) {
    pending.get(msg.id)(msg.result || msg.error);
    pending.delete(msg.id);
  }
};

async function sendCommand(method, params = {}) {
  const id = idCounter++;
  return new Promise((resolve, reject) => {
    pending.set(id, (res) => {
      if (res && res.message) reject(new Error(res.message));
      else resolve(res);
    });
    ws.send(JSON.stringify({ id, method, params }));
  });
}

try {
  const targetResponse = await sendCommand("Target.createTarget", { url: "about:blank" });
  const targetId = targetResponse.targetId;

  const sessionResponse = await sendCommand("Target.attachToTarget", { targetId, flatten: true });
  const sessionId = sessionResponse.sessionId;

  async function sendSessionCommand(method, params = {}) {
    const id = idCounter++;
    return new Promise((resolve, reject) => {
      pending.set(id, (res) => {
        if (res && res.message) reject(new Error(res.message));
        else resolve(res);
      });
      ws.send(JSON.stringify({ sessionId, id, method, params }));
    });
  }

  await sendSessionCommand("Page.enable");
  await sendSessionCommand("Page.navigate", { url });
  
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      ws.removeEventListener('message', listener);
      console.warn("Page.loadEventFired timed out after 30 seconds, proceeding anyway.");
      resolve();
    }, 30000);

    const listener = (event) => {
      const msg = JSON.parse(event.data);
      if (msg.method === "Page.loadEventFired" && msg.sessionId === sessionId) {
        clearTimeout(timeout);
        ws.removeEventListener('message', listener);
        resolve();
      }
    };
    ws.addEventListener('message', listener);
  });

  const userScriptContent = await Deno.readTextFile(userScriptPath);
  
  const evalResult = await sendSessionCommand("Runtime.evaluate", {
    expression: `
      (async () => {
        try {
          let modStr = ` + JSON.stringify(userScriptContent) + `;
          if (!modStr.includes('export ')) {
            modStr += '\\nexport { extract };';
          }
          const dataUri = 'data:text/javascript;charset=utf-8,' + encodeURIComponent(modStr);
          const m = await import(dataUri);
          if (typeof m.extract !== 'function') {
            throw new Error('Script must define or export an async function named "extract".');
          }
          const targetUrl = ` + JSON.stringify(url) + `;
          const res = await m.extract(targetUrl);
          return res;
        } catch(e) {
          throw e;
        }
      })()
    `,
    awaitPromise: true,
    returnByValue: true
  });

  if (evalResult.exceptionDetails) {
    const errText = evalResult.exceptionDetails.exception?.description || evalResult.exceptionDetails.text;
    if (errText.includes('Deno is not defined') || errText.includes('Deno.')) {
      throw new Error("Extractor error: Deno APIs are not available in the browser context. Extractors must use standard DOM APIs. " + errText);
    } else {
      throw new Error("Extractor error: " + errText);
    }
  } else {
    console.log(JSON.stringify(evalResult.result.value));
  }

} catch(e) {
  console.error("Extractor error:", e.message || e);
  Deno.exitCode = 1;
} finally {
  try { ws.close(); } catch(_) {}
  try { browserProcess.kill("SIGTERM"); } catch(_) {}
}
''';
      await wrapperScriptFile.writeAsString(wrapperScript);

      final env = <String, String>{};
      if (browser != null && browser.capability == BrowserCapability.chromium) {
        // Find executable if it's a known generic name, but here we just pass the ID as executable
        // Actually, BrowserDetector id might just be "google-chrome". Puppeteer can use this directly.
        env['PUPPETEER_EXECUTABLE_PATH'] = browser.id;
      }

      final process = await Process.start(
        DenoRuntime.managedPath,
        ['run', '--allow-all', wrapperScriptFile.path, url, userScriptFile.path],
        environment: env,
      );

      final outLogs = <String>[];
      final errLogs = <String>[];
      final allLogs = <String>[];
      
      void log(String line) {
        allLogs.add(line);
        onLog?.call(line);
      }

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        outLogs.add(line);
        log(line);
      });

      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        errLogs.add(line);
        log(line);
      });

      final exitCode = await process.exitCode;
      final fullLogs = allLogs.join('\n');

      if (exitCode != 0) {
        throw ExtractorException('Extractor failed (exit code $exitCode):\n${errLogs.join('\n')}', fullLogs);
      }

      if (outLogs.isEmpty) {
        return ExtractorResult([], fullLogs);
      }

      // The last line of stdout should be our JSON array
      final jsonStr = outLogs.last;
      try {
        final decoded = jsonDecode(jsonStr);
        if (decoded is! List) {
          throw const FormatException('Extractor result must be an array of URL strings.');
        }

        final resultUrls = <String>[];
        for (final item in decoded) {
          if (item is! String) {
            throw const FormatException('Extractor result must be an array of URL strings.');
          }
          final urlStr = item.trim();
          if (urlStr.isEmpty) {
            throw const FormatException('Extractor returned an empty URL string.');
          }
          final uri = Uri.tryParse(urlStr);
          if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
            throw const FormatException('Extractor returned an invalid URL string.');
          }
          resultUrls.add(urlStr);
        }
        
        return ExtractorResult(resultUrls, fullLogs);
      } on FormatException catch (e) {
        throw ExtractorException(e.message, fullLogs);
      } catch (e) {
        throw ExtractorException('Failed to parse extractor output: $e\nOutput was: $jsonStr', fullLogs);
      }
    } finally {
      // Clean up temp dir
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }
}
