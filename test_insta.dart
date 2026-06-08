import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final url = 'https://www.instagram.com/instagram/';
  final username = 'instagram';
  
  final client = HttpClient();
  try {
    client.connectionTimeout = const Duration(seconds: 8);
    final req = await client.getUrl(
      Uri.parse('https://www.instagram.com/api/v1/users/web_profile_info/?username=$username'),
    );
    req.headers.set(
      'User-Agent',
      'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
    );
    req.headers.set('X-IG-App-ID', '936619743392459');
    req.headers.set('X-Requested-With', 'XMLHttpRequest');
    req.headers.set('Referer', 'https://www.instagram.com/');

    final res = await req.close();
    print('Status: ${res.statusCode}');
    if (res.statusCode != 200) {
      print('Failed');
      return;
    }

    final output = await res.transform(utf8.decoder).join();
    final data = jsonDecode(output) as Map<String, dynamic>;
    final user = data['data']?['user'] as Map<String, dynamic>? ?? {};
    final count = user['edge_owner_to_timeline_media']?['count'] as int? ?? 0;
    print('Count: $count');
    final edges = user['edge_owner_to_timeline_media']?['edges'] as List<dynamic>? ?? [];
    print('Edges: ${edges.length}');
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
