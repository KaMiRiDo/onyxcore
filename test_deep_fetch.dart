import 'dart:io';
import 'dart:convert';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/gallery_dl_engine.dart';
import 'package:onyxcore/features/downloader/services/cookie_helper.dart';

void main() async {
  final url = 'https://www.instagram.com/rashmika_mandanna/';
  final browser = 'firefox';
  
  final cookies = await CookieHelper.extractCookies(browser);

  final client = HttpClient();
  try {
    final req = await client.getUrl(
      Uri.parse(
        'https://www.instagram.com/api/v1/users/web_profile_info/?username=rashmika_mandanna',
      ),
    );
    if (cookies != null) {
      req.headers.set('Cookie', cookies);
    }
    req.headers.set(
      'User-Agent',
      'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
    );
    req.headers.set('X-IG-App-ID', '936619743392459');
    req.headers.set('X-Requested-With', 'XMLHttpRequest');

    final res = await req.close();
    final output = await res.transform(utf8.decoder).join();
    
    final data = jsonDecode(output) as Map<String, dynamic>;
    final user = data['data']?['user'] as Map<String, dynamic>? ?? {};

    final edges = user['edge_owner_to_timeline_media']?['edges'] as List<dynamic>? ?? [];
    print('Fetched \${edges.length} edges.');
    
    for (final edge in edges) {
      final node = edge['node'] as Map<String, dynamic>?;
      if (node == null) continue;
      print('Item \${node['shortcode']} isVideo: \${node['is_video']}');
    }
  } finally {
    client.close();
  }
}
