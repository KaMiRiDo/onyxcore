import 'dart:io';
import 'dart:convert';

void main() async {
  final res = await Process.run('/home/vimal-babu/.local/share/onyxcore/bin/gallery-dl', ['--cookies-from-browser', 'firefox', '-j', 'https://www.instagram.com/reel/C-5_7Huvl6b/']);
  final output = res.stdout as String;
  final lines = output.split('\n');
  String? url;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      final json = jsonDecode(line);
      if (json is List && json.length > 1) {
        final data = json[1];
        if (data is Map && data.containsKey('originalUrl')) {
          continue;
        }
      }
      final urlMatch = RegExp(r'"(https://[^"]+cdninstagram\.com[^"]+)"').firstMatch(line);
      if (urlMatch != null) {
        url = urlMatch.group(1);
        break;
      }
    } catch (_) {}
  }
  
  if (url != null) {
    print('Found URL: $url');
    final curlRes = await Process.run('curl', ['-sI', '-A', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', url]);
    print(curlRes.stdout);
  } else {
    print('No URL found');
  }
}
