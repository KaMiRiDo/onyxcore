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
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0');
    req.headers.set('Referer', 'https://www.instagram.com/');
    final response = await req.close();
    print('Status: ${response.statusCode}');
    print('Content-Length: ${response.contentLength}');
    response.listen((_) {}).cancel();
  } else {
    print('No URL found');
  }
}
