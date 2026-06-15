import 'dart:io';
import 'package:path/path.dart' as p;

class MediaUriHelper {
  static HttpServer? _localProxy;
  static final Map<String, String> _proxyMap = {};

  static Future<void> ensureLocalProxy() async {
    if (_localProxy != null) return;
    try {
      _localProxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _localProxy!.listen((HttpRequest request) async {
        final targetPath = _proxyMap[request.uri.path];
        if (targetPath != null) {
          final file = File(targetPath);
          if (await file.exists()) {
            final length = await file.length();
            final rangeHeader = request.headers.value('range');
            if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
              final parts = rangeHeader.substring(6).split('-');
              final start = int.parse(parts[0]);
              final end = parts.length > 1 && parts[1].isNotEmpty
                  ? int.parse(parts[1])
                  : length - 1;
              request.response.statusCode = HttpStatus.partialContent;
              request.response.headers.add(
                'Content-Range',
                'bytes $start-$end/$length',
              );
              request.response.headers.add(
                'Content-Length',
                '${end - start + 1}',
              );
              request.response.headers.add('Accept-Ranges', 'bytes');
              await request.response.addStream(file.openRead(start, end + 1));
            } else {
              request.response.headers.add('Content-Length', '$length');
              request.response.headers.add('Accept-Ranges', 'bytes');
              await request.response.addStream(file.openRead());
            }
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });
    } catch (e) {
      // Fallback if proxy fails to bind
    }
  }

  static String getSafeMediaUri(String path) {
    if (!path.contains('\\')) {
      return Uri.file(path).toString();
    }

    final id = '/${path.hashCode.abs()}';
    _proxyMap[id] = path;
    if (_localProxy == null) {
      return Uri.file(path).toString(); // Fallback if proxy not initialized
    }
    return 'http://127.0.0.1:${_localProxy!.port}$id';
  }
}
