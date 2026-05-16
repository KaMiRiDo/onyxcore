import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AppInfo {
  final String id;
  final String name;
  final String exec;
  final String? icon;
  final List<String> mimeTypes;
  final String desktopFilePath;

  AppInfo({
    required this.id,
    required this.name,
    required this.exec,
    this.icon,
    required this.mimeTypes,
    required this.desktopFilePath,
  });

  @override
  String toString() => 'AppInfo(name: $name, id: $id)';
}

class AppLauncherUtils {
  static Map<String, String> _iconCache = {};
  static bool _iconsScanned = false;
  static List<AppInfo> _cachedApps = [];
  static bool _isScanning = false;
  static final Map<String, String> _extensionMimeCache = {};
  static final Map<String, List<String>> _mimeRecommendedCache = {};

  static List<AppInfo> get cachedApps => _cachedApps;
  static bool get isScanning => _isScanning;

  static Future<void> init() async {
    if (_cachedApps.isEmpty) {
      await _preScanIcons();
      await scanApps();
    }
  }

  static Future<void> refresh() async {
    _iconsScanned = false;
    _iconCache.clear();
    _extensionMimeCache.clear();
    _mimeRecommendedCache.clear();
    await _preScanIcons();
    await scanApps();
  }

  static Future<List<AppInfo>> scanApps() async {
    _isScanning = true;
    final List<AppInfo> apps = [];
    final scanPaths = [
      '/usr/share/applications',
      '/usr/local/share/applications',
      p.join(Platform.environment['HOME'] ?? '', '.local/share/applications'),
      '/var/lib/flatpak/exports/share/applications',
      p.join(Platform.environment['HOME'] ?? '', '.local/share/flatpak/exports/share/applications'),
      '/var/lib/snapd/desktop/applications',
      '/var/lib/snapd/desktop/applications', // Double check
    ];

    final Set<String> processedIds = {};

    for (final path in scanPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          final entities = await dir.list().toList();
          for (final entity in entities) {
            if (entity is File && entity.path.endsWith('.desktop')) {
              try {
                final id = p.basename(entity.path);
                // We allow duplicates if the path is different and name is different
                // but usually id is enough
                if (processedIds.contains(id)) continue;
                
                final app = await _parseDesktopFile(entity);
                if (app != null) {
                  apps.add(app);
                  processedIds.add(id);
                }
              } catch (e) {
                debugPrint('Error parsing $entity: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('Error scanning apps in $path: $e');
        }
      }
    }

    // Sort alphabetically
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    _cachedApps = apps;
    _isScanning = false;
    return apps;
  }

  static Future<void> _preScanIcons() async {
    if (_iconsScanned) return;
    final iconPaths = [
      '/usr/share/icons',
      '/usr/share/pixmaps',
      p.join(Platform.environment['HOME'] ?? '', '.local/share/icons'),
    ];

    int iconCount = 0;
    for (final rootPath in iconPaths) {
      final root = Directory(rootPath);
      if (!root.existsSync()) continue;

      try {
        final entities = root.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final path = entity.path;
            // We only care about icons in 'apps', 'mimetypes', or pixmaps
            if (!path.contains('/apps/') && !path.contains('/mimetypes/') && !path.contains('pixmaps')) continue;

            final ext = p.extension(path).toLowerCase();
            if (['.png', '.svg', '.xpm', '.jpg', '.jpeg'].contains(ext)) {
              // Strip only the image extension, preserving dotted names like org.gnome.TextEditor
              final basename = p.basename(path);
              final name = basename.substring(0, basename.length - ext.length);
              
              // Priority: Scalable > High Res > Medium Res
              bool shouldUpdate = !_iconCache.containsKey(name);
              if (!shouldUpdate) {
                final currentPath = _iconCache[name]!;
                final isNewScalable = path.contains('scalable');
                final isCurrentScalable = currentPath.contains('scalable');
                
                if (isNewScalable && !isCurrentScalable) {
                  shouldUpdate = true;
                } else if (!isCurrentScalable) {
                  if (path.contains('256x256') || path.contains('512x512')) shouldUpdate = true;
                  else if (path.contains('128x128') && !currentPath.contains('256x256')) shouldUpdate = true;
                  else if (path.contains('64x64') && !currentPath.contains('128x128') && !currentPath.contains('256x256')) shouldUpdate = true;
                  else if (path.contains('48x48') && !currentPath.contains('64x64')) shouldUpdate = true;
                }
              }

              if (shouldUpdate) {
                _iconCache[name] = path;
                iconCount++;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error pre-scanning icons in $rootPath: $e');
      }
    }
    debugPrint('Pre-scanned $iconCount unique icons');
    _iconsScanned = true;
  }

  static Future<AppInfo?> _parseDesktopFile(File file) async {
    try {
      final List<String> lines = await file.readAsLines();
      String? name;
      String? exec;
      String? icon;
      final List<String> mimeTypes = [];
      bool isNoDisplay = false;
      bool inDesktopEntry = false;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
          inDesktopEntry = (trimmed == '[Desktop Entry]');
          continue;
        }

        if (!inDesktopEntry) continue;

        final parts = trimmed.split('=');
        if (parts.length < 2) continue;
        
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();

        if (key == 'Name') {
          name = value;
        } else if (key == 'Exec') {
          // Remove %f, %F, %u, %U etc
          exec = value.replaceAll(RegExp(r'%[fFuU]'), '').trim();
        } else if (key == 'Icon') {
          icon = value;
        } else if (key == 'MimeType') {
          mimeTypes.addAll(value.split(';').where((e) => e.isNotEmpty));
        } else if (key == 'NoDisplay' && value.toLowerCase() == 'true') {
          isNoDisplay = true;
        }
      }

      if (name != null && exec != null && !isNoDisplay) {
        return AppInfo(
          id: p.basenameWithoutExtension(file.path),
          name: name,
          exec: exec,
          icon: _resolveIconPath(icon),
          mimeTypes: mimeTypes,
          desktopFilePath: file.path,
        );
      }
    } catch (e) {
      // Some files might be encoded differently, try to read as bytes if readAsLines fails
      try {
        final bytes = await file.readAsBytes();
        final content = String.fromCharCodes(bytes);
        // Basic parsing for fallback
        if (content.contains('Name=') && content.contains('Exec=')) {
           // We could implement a more complex fallback but most are UTF-8
        }
      } catch (_) {}
    }
    return null;
  }

  static String? _resolveIconPath(String? iconName) {
    if (iconName == null) return null;
    if (iconName.startsWith('/')) return iconName;

    // Use the icon name directly for lookup (don't strip dots from names like org.gnome.TextEditor)
    if (_iconCache.containsKey(iconName)) {
      return _iconCache[iconName];
    }

    // Try with -symbolic suffix (some GNOME apps only have symbolic icons)
    final symbolicName = '$iconName-symbolic';
    if (_iconCache.containsKey(symbolicName)) {
      return _iconCache[symbolicName];
    }

    // Fallback: if the name had a file extension, strip just that
    final ext = p.extension(iconName).toLowerCase();
    if (['.png', '.svg', '.xpm'].contains(ext)) {
      final stripped = iconName.substring(0, iconName.length - ext.length);
      if (_iconCache.containsKey(stripped)) {
        return _iconCache[stripped];
      }
    }

    return null;
  }

  static Future<List<AppInfo>> getRecommendedApps(String filePath) async {
    final mimeType = await _getMimeType(filePath);
    if (mimeType == null) return [];

    if (_mimeRecommendedCache.containsKey(mimeType)) {
      final recommendedIds = _mimeRecommendedCache[mimeType]!;
      return _cachedApps.where((app) => recommendedIds.contains(app.id) || recommendedIds.contains('${app.id}.desktop')).toList();
    }

    try {
      final result = await Process.run('gio', ['mime', mimeType]);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final recommendedIds = _parseGioMimeOutput(output);
        _mimeRecommendedCache[mimeType] = recommendedIds;
        return _cachedApps.where((app) => recommendedIds.contains(app.id) || recommendedIds.contains('${app.id}.desktop')).toList();
      }
    } catch (e) {
      print('Error getting recommended apps: $e');
    }
    
    // Fallback: search by mime type in cached apps
    return _cachedApps.where((app) => app.mimeTypes.contains(mimeType)).toList();
  }

  static Future<AppInfo?> getDefaultApp(String filePath) async {
    final mimeType = await _getMimeType(filePath);
    if (mimeType == null) return null;

    try {
      final result = await Process.run('gio', ['mime', mimeType]);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains('Default application')) {
            final parts = line.split(':');
            if (parts.length > 1) {
              final id = parts[1].trim().replaceAll('.desktop', '');
              return _cachedApps.firstWhere((app) => app.id == id, orElse: () => _cachedApps.firstWhere((app) => app.id == '$id.desktop', orElse: () => _cachedApps[0]));
            }
          }
        }
      }
    } catch (e) {
      print('Error getting default app: $e');
    }
    return null;
  }

  static Future<String?> _getMimeType(String filePath) async {
    final ext = p.extension(filePath).toLowerCase();
    if (_extensionMimeCache.containsKey(ext)) return _extensionMimeCache[ext];

    try {
      final result = await Process.run('gio', ['info', '-a', 'standard::content-type', filePath]);
      if (result.exitCode == 0) {
        final output = result.stdout as String;
        final match = RegExp(r'standard::content-type:\s+(.+)').firstMatch(output);
        final mimeType = match?.group(1)?.trim();
        if (mimeType != null) {
          _extensionMimeCache[ext] = mimeType;
        }
        return mimeType;
      }
    } catch (e) {}
    return null;
  }

  static List<String> _parseGioMimeOutput(String output) {
    final List<String> ids = [];
    final lines = output.split('\n');
    bool inRecommended = false;

    for (final line in lines) {
      if (line.contains('Recommended applications:')) {
        inRecommended = true;
        continue;
      }
      if (inRecommended) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) break;
        ids.add(trimmed);
      }
    }
    return ids;
  }

  static Future<void> launchApp(AppInfo app, String filePath) async {
    // Replace %u, %U, %f, %F with file path
    String exec = app.exec;
    final path = '"$filePath"';
    
    if (exec.contains('%u') || exec.contains('%U') || exec.contains('%f') || exec.contains('%F')) {
      exec = exec.replaceAll('%u', path).replaceAll('%U', path).replaceAll('%f', path).replaceAll('%F', path);
    } else {
      exec = '$exec $path';
    }

    // Run as background process
    // We use /bin/sh to handle the command properly
    Process.start('sh', ['-c', exec]);
  }
}
