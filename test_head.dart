import 'dart:io';

void main() async {
  final client = HttpClient();
  final req = await client.headUrl(Uri.parse('https://www.instagram.com/p/DFzL1l7NfKk/'));
  req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
  final res = await req.close();
  print('Status: ${res.statusCode}');
  print('Content-Length: ${res.contentLength}');
  res.headers.forEach((name, values) {
    print('$name: $values');
  });
}
