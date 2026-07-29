import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/app_launcher_utils.dart';

base class MockAppLauncherIOOverrides extends IOOverrides {
  MockAppLauncherIOOverrides(this.tempDir);
  final Directory tempDir;

  @override
  Directory createDirectory(String path) {
    if (path.startsWith('/usr/share/applications') ||
        path.startsWith('/usr/local/share/applications') ||
        path.contains('.local/share/applications') ||
        path.contains('flatpak/exports/share/applications') ||
        path.contains('snapd/desktop/applications')) {
      return super.createDirectory('${tempDir.path}/applications');
    }
    if (path.startsWith('/usr/share/icons')) {
      final relative = path.substring('/usr/share/icons'.length);
      return super.createDirectory('${tempDir.path}/icons$relative');
    }
    if (path.startsWith('/usr/share/pixmaps')) {
      final relative = path.substring('/usr/share/pixmaps'.length);
      return super.createDirectory('${tempDir.path}/pixmaps$relative');
    }
    if (path.contains('.local/share/icons')) {
      final index = path.indexOf('.local/share/icons');
      final relative = path.substring(index + '.local/share/icons'.length);
      return super.createDirectory('${tempDir.path}/icons$relative');
    }
    return super.createDirectory(path);
  }

  @override
  File createFile(String path) {
    if (path.contains('/applications/')) {
      final name = path.substring(path.lastIndexOf('/') + 1);
      return super.createFile('${tempDir.path}/applications/$name');
    }
    if (path.contains('/icons/')) {
      final index = path.indexOf('/icons/');
      final relative = path.substring(index + '/icons/'.length);
      return super.createFile('${tempDir.path}/icons/$relative');
    }
    if (path.contains('/pixmaps/')) {
      final index = path.indexOf('/pixmaps/');
      final relative = path.substring(index + '/pixmaps/'.length);
      return super.createFile('${tempDir.path}/pixmaps/$relative');
    }
    return super.createFile(path);
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('app_launcher_test_');
    AppLauncherUtils.runProcess = Process.run;
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('AppInfo', () {
    test('constructor and toString works correctly', () {
      final app = AppInfo(
        id: 'test-app',
        name: 'Test App',
        exec: 'test-app-exec',
        mimeTypes: ['image/png'],
        desktopFilePath: '/path/to/test-app.desktop',
        icon: '/path/to/icon.png',
      );

      expect(app.id, 'test-app');
      expect(app.name, 'Test App');
      expect(app.exec, 'test-app-exec');
      expect(app.mimeTypes, ['image/png']);
      expect(app.desktopFilePath, '/path/to/test-app.desktop');
      expect(app.icon, '/path/to/icon.png');
      expect(app.toString(), contains('Test App'));
    });
  });

  group('AppLauncherUtils', () {
    test('scans apps, parses desktop files, and handles NoDisplay correctly', () async {
      await IOOverrides.runWithIOOverrides(() async {
        final appsDir = Directory('${tempDir.path}/applications')..createSync(recursive: true);

        // Valid app
        File('${appsDir.path}/test-app.desktop').writeAsStringSync('''
[Desktop Entry]
Name=Test App
Exec=test-app %f
Icon=/path/to/icon.png
MimeType=image/png;image/jpeg;
NoDisplay=false
''');

        // Hidden app (NoDisplay=true)
        File('${appsDir.path}/hidden-app.desktop').writeAsStringSync('''
[Desktop Entry]
Name=Hidden App
Exec=hidden-app
NoDisplay=true
''');

        // Invalid line / comments
        File('${appsDir.path}/invalid-app.desktop').writeAsStringSync('''
# Comments here
[Some Other Entry]
Name=Invalid
[Desktop Entry]
Name=Invalid App
Exec=invalid-app
''');

        await AppLauncherUtils.refresh();

        final apps = AppLauncherUtils.cachedApps;
        expect(apps.any((app) => app.id == 'test-app'), isTrue);
        expect(apps.any((app) => app.id == 'hidden-app'), isFalse);
        expect(apps.any((app) => app.id == 'invalid-app'), isTrue); // valid entry was found after header switch
      }, MockAppLauncherIOOverrides(tempDir));
    });

    test('pre-scans icons with priority: scalable > high-res > low-res', () async {
      await IOOverrides.runWithIOOverrides(() async {
        final iconsDir = Directory('${tempDir.path}/icons')..createSync(recursive: true);

        // We want to test different resolution paths
        final path48 = Directory('${iconsDir.path}/48x48/apps')..createSync(recursive: true);
        final path256 = Directory('${iconsDir.path}/256x256/apps')..createSync(recursive: true);
        final pathScalable = Directory('${iconsDir.path}/scalable/apps')..createSync(recursive: true);

        File('${path48.path}/test-icon.png').createSync();
        File('${path256.path}/test-icon.png').createSync();
        final fileScalable = File('${pathScalable.path}/test-icon.svg')..createSync();

        final appsDir = Directory('${tempDir.path}/applications')..createSync(recursive: true);
        File('${appsDir.path}/icon-priority-app.desktop').writeAsStringSync('''
[Desktop Entry]
Name=Priority App
Exec=priority-app
Icon=test-icon
MimeType=image/png;
NoDisplay=false
''');

        await AppLauncherUtils.refresh();

        final apps = AppLauncherUtils.cachedApps;
        final app = apps.firstWhere((app) => app.id == 'icon-priority-app');
        // Scalable should be preferred over others
        expect(app.icon, fileScalable.path);
      }, MockAppLauncherIOOverrides(tempDir));
    });

    test('resolves symbolic icons and stripped extensions', () async {
      await IOOverrides.runWithIOOverrides(() async {
        final iconsDir = Directory('${tempDir.path}/icons')..createSync(recursive: true);
        final appsDir = Directory('${tempDir.path}/applications')..createSync(recursive: true);

        final fileSymbolic = File('${iconsDir.path}/pixmaps/test-icon-symbolic.png')..createSync(recursive: true);
        final fileStripped = File('${iconsDir.path}/pixmaps/test-icon-stripped.png')..createSync(recursive: true);

        File('${appsDir.path}/symbolic-app.desktop').writeAsStringSync('''
[Desktop Entry]
Name=Symbolic App
Exec=symbolic-app
Icon=test-icon
''');

        File('${appsDir.path}/stripped-app.desktop').writeAsStringSync('''
[Desktop Entry]
Name=Stripped App
Exec=stripped-app
Icon=test-icon-stripped.png
''');

        await AppLauncherUtils.refresh();

        final apps = AppLauncherUtils.cachedApps;
        final sym = apps.firstWhere((app) => app.id == 'symbolic-app');
        expect(sym.icon, fileSymbolic.path);

        final strip = apps.firstWhere((app) => app.id == 'stripped-app');
        expect(strip.icon, fileStripped.path);
      }, MockAppLauncherIOOverrides(tempDir));
    });

    test('mocked process getRecommendedApps and getDefaultApp', () async {
      await IOOverrides.runWithIOOverrides(() async {
        final appsDir = Directory('${tempDir.path}/applications')..createSync(recursive: true);
        File('${appsDir.path}/test-app.desktop').writeAsStringSync('''
[Desktop Entry]
Name=Test App
Exec=test-app %f
MimeType=image/png;
''');

        await AppLauncherUtils.refresh();

        // 1. Mock _getMimeType process success
        AppLauncherUtils.runProcess = (String executable, List<String> arguments) async {
          if (executable == 'gio' && arguments[0] == 'info') {
            return ProcessResult(0, 0, 'standard::content-type: image/png\n', '');
          }
          if (executable == 'gio' && arguments[0] == 'mime') {
            return ProcessResult(0, 0, '''
Default application: test-app.desktop
Recommended applications:
  test-app.desktop
''', '');
          }
          return ProcessResult(0, 1, '', 'unknown command');
        };

        final recommended = await AppLauncherUtils.getRecommendedApps('file.png');
        expect(recommended.any((app) => app.id == 'test-app'), isTrue);

        final defaultApp = await AppLauncherUtils.getDefaultApp('file.png');
        expect(defaultApp?.id, 'test-app');
      }, MockAppLauncherIOOverrides(tempDir));
    });

    test('launchApp replaces placeholders correctly', () async {
      final app = AppInfo(
        id: 'placeholder-app',
        name: 'Placeholder App',
        exec: 'echo %f %F %u %U',
        mimeTypes: ['text/plain'],
        desktopFilePath: '/dev/null',
      );

      await expectLater(AppLauncherUtils.launchApp(app, 'hello'), completes);
    });

    test('mocked process failures in getRecommendedApps and getDefaultApp', () async {
      await IOOverrides.runWithIOOverrides(() async {
        final appsDir = Directory('${tempDir.path}/applications')..createSync(recursive: true);
        File('${appsDir.path}/test-app.desktop').writeAsStringSync('''
[Desktop Entry]
Name=Test App
Exec=test-app %f
MimeType=image/png;
''');

        await AppLauncherUtils.refresh();

        // Mock process throwing exception
        AppLauncherUtils.runProcess = (String executable, List<String> arguments) async {
          throw ProcessException(executable, arguments);
        };

        final recommended = await AppLauncherUtils.getRecommendedApps('file.png');
        expect(recommended, isEmpty);

        final defaultApp = await AppLauncherUtils.getDefaultApp('file.png');
        expect(defaultApp, isNull);
      }, MockAppLauncherIOOverrides(tempDir));
    });

    test('handles non-UTF-8 desktop file encoding gracefully', () async {
      await IOOverrides.runWithIOOverrides(() async {
        final appsDir = Directory('${tempDir.path}/applications')..createSync(recursive: true);
        final file = File('${appsDir.path}/non-utf8-app.desktop');
        
        // Write invalid UTF-8 bytes to trigger the try-catch block
        await file.writeAsBytes([0x80, 0x81, 0x82, 0x83]);

        await expectLater(AppLauncherUtils.refresh(), completes);
      }, MockAppLauncherIOOverrides(tempDir));
    });
  });
}
