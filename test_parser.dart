import 'dart:convert';

void main() {
  final jsonString = '''
[
  [
    6,
    "https://www.instagram.com/rashmika_mandanna/posts/",
    {
      "category": "instagram",
      "subcategory": "user"
    }
  ]
]
''';

  final block = jsonString;
  final url = 'https://www.instagram.com/rashmika_mandanna/';
  final isSocialProfile = true;
  final existingCount = 0;
  final fileCount = 0;

  final json = jsonDecode(block);
  final parsedInfos = [];

  if (json is List) {
    bool isListOfEvents = json.isNotEmpty && json.first is List;
    List<dynamic> events = isListOfEvents ? json : [json];
    Map<String, dynamic> sharedMeta = {};

    for (final event in events) {
      if (event is List && event.isNotEmpty) {
        final eventType = event[0];
        final metaIndex = event.indexWhere((e) => e is Map);
        if (metaIndex != -1) {
          sharedMeta.addAll(
            Map<String, dynamic>.from(event[metaIndex] as Map),
          );
        }
        // skipping event == 3 logic since it's 6
      }
    }

    bool hasProfileData = sharedMeta.containsKey('user') || sharedMeta.containsKey('username') || (sharedMeta['subcategory'] == 'user' && sharedMeta['category'] == 'instagram');
    print('hasProfileData: \$hasProfileData');
    
    if (isSocialProfile && sharedMeta.isNotEmpty && existingCount == 0 && (fileCount > 0 || hasProfileData)) {
      String title = '';
      if (title.isEmpty) {
        if (url.contains('instagram.com/')) {
          final uri = Uri.tryParse(url);
          if (uri != null && uri.pathSegments.isNotEmpty) {
            title = '@\${uri.pathSegments.first}';
          }
        }
      }
      print('Parsed Title: \$title');
    } else {
      print('Did not enter if block');
    }
  }
}
