import 'dart:io';
import 'dart:convert';
import 'package:onyxcore/features/downloader/services/cookie_helper.dart';

void main() async {
  final url = 'https://www.instagram.com/rashmika_mandanna/';
  final username = 'rashmika_mandanna';
  final browser = 'firefox';
  
  final cookies = await CookieHelper.extractCookies(browser);
  print('Cookies extracted: ${cookies != null}');

  final client = HttpClient();
  try {
    client.connectionTimeout = const Duration(seconds: 8);
    final req = await client.getUrl(
      Uri.parse(
        'https://www.instagram.com/api/v1/users/web_profile_info/?username=$username',
      ),
    );
    if (cookies != null && cookies.isNotEmpty) {
      req.headers.set('Cookie', cookies);
    }
    req.headers.set(
      'User-Agent',
      'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
    );
    req.headers.set('X-IG-App-ID', '936619743392459');
    req.headers.set('X-Requested-With', 'XMLHttpRequest');
    req.headers.set('Referer', 'https://www.instagram.com/');

    final res = await req.close();
    print('Status Code: ${res.statusCode}');
    final output = await res.transform(utf8.decoder).join();
    print('Output length: ${output.length}');
    try {
      final data = jsonDecode(output) as Map<String, dynamic>;
      final user = data['data']?['user'] as Map<String, dynamic>? ?? {};
      print('User keys: ${user.keys.toList()}');
    } catch (e) {
      print('Parse error: $e');
    }
  } finally {
    client.close();
  }
}
