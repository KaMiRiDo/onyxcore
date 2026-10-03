import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/features/downloader/domain/entities/browser_capability.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/domain/entities/extractor_runtime_config.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_output_validator.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_runtime_service.dart';
import 'package:onyxcore/features/downloader/services/deno_runtime.dart';

typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  bool runInShell,
});

class DenoExtractorRuntimeService implements ExtractorRuntimeService {
  final ProcessStarter processStarter;

  DenoExtractorRuntimeService({
    @visibleForTesting this.processStarter = Process.start,
  });

  @override
  Future<ExtractorResult> execute(
    CustomExtractor extractor,
    String url, {
    BrowserInfo? browser,
    ExtractorRuntimeConfig? config,
    void Function(String)? onLog,
    void Function(int pid)? onProcessStarted,
  }) async {
    final runtimeConfig = config ?? const ExtractorRuntimeConfig();
    final tempDir = await Directory.systemTemp.createTemp('onyx_extractor_');
    Process? process;

    try {
      final userScriptFile = File('${tempDir.path}/user_script.js');
      await userScriptFile.writeAsString(extractor.script);

      final wrapperScriptFile = File('${tempDir.path}/wrapper.js');
      const wrapperScript = r'''
const executablePath = Deno.env.get("PUPPETEER_EXECUTABLE_PATH");
const url = Deno.args[0];
const userScriptPath = Deno.args[1];
const navigationTimeoutMs = parseInt(Deno.args[2], 10);
const settleDelayMs = parseInt(Deno.args[3], 10);

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

Deno.addSignalListener("SIGINT", () => {
  try { browserProcess.kill("SIGTERM"); } catch(_) {}
  Deno.exit(1);
});
Deno.addSignalListener("SIGTERM", () => {
  try { browserProcess.kill("SIGTERM"); } catch(_) {}
  Deno.exit(1);
});

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
  
  // Hard navigation timeout
  const navigatePromise = sendSessionCommand("Page.navigate", { url });
  
  const navTimeoutPromise = new Promise((_, reject) => {
    setTimeout(() => reject(new Error("Navigation timeout exceeded (" + navigationTimeoutMs + "ms)")), navigationTimeoutMs);
  });
  
  await Promise.race([navigatePromise, navTimeoutPromise]);
  
  // Wait for loadEventFired with timeout
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      ws.removeEventListener('message', listener);
      reject(new Error("Page.loadEventFired timeout exceeded (" + navigationTimeoutMs + "ms)"));
    }, navigationTimeoutMs);

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
  
  if (settleDelayMs > 0) {
    await new Promise(r => setTimeout(r, settleDelayMs));
  }

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
  
  try { ws.close(); } catch(_) {}
  try { browserProcess.kill("SIGTERM"); } catch(_) {}
  Deno.exit(0);

} catch(e) {
  console.error("Extractor error:", e.message || e);
  try { ws.close(); } catch(_) {}
  try { browserProcess.kill("SIGTERM"); } catch(_) {}
  Deno.exit(1);
}
''';
      await wrapperScriptFile.writeAsString(wrapperScript);

      final env = <String, String>{};
      String? executablePath;

      if (browser != null && browser.capability == BrowserCapability.chromium) {
        // Resolve the browser ID to a real executable path
        try {
          final res = await Process.run('which', [browser.id]);
          if (res.exitCode == 0) {
            executablePath = res.stdout.toString().trim();
          }
        } catch (_) {}
      }

      if (executablePath == null || executablePath.isEmpty) {
        throw ExtractorException('Browser executable not found for: ${browser?.name ?? "unknown"}', '');
      }

      env['PUPPETEER_EXECUTABLE_PATH'] = executablePath;

      // Lock down permissions. Only allow execution of the browser, network for websocket, and file access for the temp dir
      final allowRun = '--allow-run=$executablePath';
      const allowNet = '--allow-net=localhost,127.0.0.1'; // Deno CDP ws connects to localhost
      final allowRead = '--allow-read=${tempDir.path}';
      final allowWrite = '--allow-write=${tempDir.path}';
      const allowEnv = '--allow-env=PUPPETEER_EXECUTABLE_PATH';

      process = await processStarter(
        DenoRuntime.managedPath,
        [
          'run',
          allowRun,
          allowNet,
          allowRead,
          allowWrite,
          allowEnv,
          wrapperScriptFile.path,
          url,
          userScriptFile.path,
          runtimeConfig.navigationTimeoutMs.toString(),
          runtimeConfig.settleDelayMs.toString(),
        ],
        environment: env,
      );
      
      onProcessStarted?.call(process.pid);

      final outLogs = <String>[];
      final errLogs = <String>[];
      final allLogs = <String>[];
      
      void log(String line) {
        // Sanitize logs to avoid exposing absolute temp dir paths
        final sanitized = line.replaceAll(tempDir.path, '<temp_dir>');
        allLogs.add(sanitized);
        onLog?.call(sanitized);
      }

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        outLogs.add(line);
        log(line);
      });

      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        errLogs.add(line);
        log(line);
      });

      // Bounded execution timeout
      final exitCode = await process.exitCode.timeout(
        Duration(milliseconds: runtimeConfig.extractorTimeoutMs),
        onTimeout: () {
          process?.kill();
          throw ExtractorException('Extractor execution timeout exceeded (${runtimeConfig.extractorTimeoutMs}ms)', allLogs.join('\n'));
        },
      );

      final fullLogs = allLogs.join('\n');

      if (exitCode != 0) {
        throw ExtractorException('Extractor failed (exit code $exitCode):\n${errLogs.map((l) => l.replaceAll(tempDir.path, '<temp_dir>')).join('\n')}', fullLogs);
      }

      if (outLogs.isEmpty) {
        return ExtractorResult([], fullLogs);
      }

      // The last line of stdout should be our JSON array
      final jsonStr = outLogs.last;
      try {
        final decoded = jsonDecode(jsonStr);
        final validatedUrls = ExtractorOutputValidator.validateRaw(decoded, config: runtimeConfig, logs: fullLogs);
        return ExtractorResult(validatedUrls, fullLogs);
      } on ExtractorException {
        rethrow;
      } catch (e) {
        throw ExtractorException('Failed to parse extractor output: $e\nOutput was: $jsonStr', fullLogs);
      }
    } finally {
      process?.kill();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  }
}
