import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_viewer_top_bar.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';

class FakeSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return const AppSettings();
  }

  @override
  Future<void> setSettingsDimensions(double width, double height) async {}

  @override
  Future<void> saveSettings(AppSettings settings) async {}
}

class FakeImageFavoritesNotifier extends ImageFavoritesNotifier {
  @override
  void setRef(Ref ref) {}

  @override
  void toggleFavorite(String path) {
    if (state.contains(path)) {
      state = {...state}..remove(path);
    } else {
      state = {...state, path};
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTopBar({
    required String title,
    required bool isStandalone,
    required bool isEmpty,
    required bool isNetworkStream,
    required String itemPath,
    required ImageFavoritesNotifier favoritesNotifier,
    String? metadata,
    VoidCallback? onPopOut,
    VoidCallback? onClose,
  }) {
    return ProviderScope(
      overrides: [
        imageFavoritesProvider.overrideWith((ref) => favoritesNotifier),
        settingsProvider.overrideWith(FakeSettingsNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ImageViewerTopBar(
            title: title,
            isStandalone: isStandalone,
            isEmpty: isEmpty,
            isNetworkStream: isNetworkStream,
            itemPath: itemPath,
            metadata: metadata,
            onPopOut: onPopOut,
            onClose: onClose,
          ),
        ),
      ),
    );
  }

  group('ImageViewerTopBar', () {
    late FakeImageFavoritesNotifier fakeFavorites;

    setUp(() {
      fakeFavorites = FakeImageFavoritesNotifier();
    });

    testWidgets('renders title and metadata correctly', (tester) async {
      await tester.pumpWidget(
        buildTopBar(
          title: 'test_title.png',
          isStandalone: false,
          isEmpty: false,
          isNetworkStream: false,
          itemPath: '/path/test_title.png',
          metadata: '1024x768 • 1.5 MB',
          favoritesNotifier: fakeFavorites,
        ),
      );

      expect(find.text('test_title.png'), findsOneWidget);
      expect(find.text('1024x768 • 1.5 MB'), findsOneWidget);
    });

    testWidgets('hides extra actions when isEmpty is true', (tester) async {
      await tester.pumpWidget(
        buildTopBar(
          title: 'test_title.png',
          isStandalone: false,
          isEmpty: true,
          isNetworkStream: false,
          itemPath: '/path/test_title.png',
          favoritesNotifier: fakeFavorites,
        ),
      );

      // Buttons like Settings, Edit, Favorite should NOT be present when empty
      expect(find.byIcon(Icons.settings_rounded), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('hides edit and favorite buttons in network stream mode', (tester) async {
      await tester.pumpWidget(
        buildTopBar(
          title: 'test_title.png',
          isStandalone: false,
          isEmpty: false,
          isNetworkStream: true,
          itemPath: 'http://example.com/stream.png',
          favoritesNotifier: fakeFavorites,
        ),
      );

      // Favorite and Edit should be hidden
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      // Settings button should still be present
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    });

    testWidgets('renders all actions and handles favorite toggle', (tester) async {
      const path = '/path/test_title.png';
      await tester.pumpWidget(
        buildTopBar(
          title: 'test_title.png',
          isStandalone: false,
          isEmpty: false,
          isNetworkStream: false,
          itemPath: path,
          favoritesNotifier: fakeFavorites,
        ),
      );

      // Verify buttons exist
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

      // Initially not a favorite, so the border icon is displayed
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();

      // Now it should be favorited (render filled heart)
      expect(fakeFavorites.state.contains(path), isTrue);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);

      // Tap again to unfavorite
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();

      expect(fakeFavorites.state.contains(path), isFalse);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });

    testWidgets('edit button is disabled (onPressed is null)', (tester) async {
      await tester.pumpWidget(
        buildTopBar(
          title: 'test_title.png',
          isStandalone: false,
          isEmpty: false,
          isNetworkStream: false,
          itemPath: '/path/test_title.png',
          favoritesNotifier: fakeFavorites,
        ),
      );

      final editIcon = find.byIcon(Icons.edit_outlined);
      final buttonFinder = find.ancestor(of: editIcon, matching: find.byType(IconButton));
      final buttonWidget = tester.widget<IconButton>(buttonFinder);
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('triggers settings dialog', (tester) async {
      await tester.pumpWidget(
        buildTopBar(
          title: 'test_title.png',
          isStandalone: false,
          isEmpty: false,
          isNetworkStream: false,
          itemPath: '/path/test_title.png',
          favoritesNotifier: fakeFavorites,
        ),
      );

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();

      // SettingsDialog should be displayed
      expect(find.byType(SettingsDialog), findsOneWidget);
      expect(find.text('SETTINGS'), findsWidgets);
    });
  });
}
