
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_canvas.dart';



void main() {
  group('ImageCanvas', () {
    testWidgets('shows BubbleLoader when isConverting is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageCanvas(
              imagePath: '/path/to/image.jpg',
              heroTag: 'test-hero',
              isConverting: true,
            ),
          ),
        ),
      );

      expect(find.byType(BubbleLoader), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('renders local raster image correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageCanvas(
              imagePath: '/path/to/image.jpg',
              heroTag: 'test-hero',
              isConverting: false,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(image.fit, equals(BoxFit.contain));
      expect(image.filterQuality, equals(FilterQuality.high));
    });

    testWidgets('renders local raster image with low filter quality during interaction', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageCanvas(
              imagePath: '/path/to/image.jpg',
              heroTag: 'test-hero',
              isConverting: false,
              isHighFrequencyInteractionActive: true,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(image.filterQuality, equals(FilterQuality.low));
    });

    testWidgets('renders network raster image correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageCanvas(
              imagePath: 'https://example.com/image.jpg',
              heroTag: 'test-hero',
              isConverting: false,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(image.fit, equals(BoxFit.contain));
      expect(image.filterQuality, equals(FilterQuality.high));
    });

    testWidgets('renders local SVG image correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageCanvas(
              imagePath: 'test/features/image_viewer/presentation/widgets/test_image.svg',
              heroTag: 'test-hero',
              isConverting: false,
            ),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
    });



    testWidgets('applies Hero tag correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageCanvas(
              imagePath: '/path/to/image.jpg',
              heroTag: 'test-hero',
              isConverting: false,
            ),
          ),
        ),
      );

      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);
      final hero = tester.widget<Hero>(heroFinder);
      expect(hero.tag, equals('test-hero'));
    });

    testWidgets('applies Transform.rotate correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageCanvas(
              imagePath: '/path/to/image.jpg',
              heroTag: 'test-hero',
              isConverting: false,
              rotationAngle: 90,
            ),
          ),
        ),
      );

      final transformFinder = find.byType(Transform);
      expect(transformFinder, findsWidgets);
      
      var foundRotation = false;
      for (final widget in tester.widgetList<Transform>(transformFinder)) {
        if (widget.transform.storage[0] < 0.001 && widget.transform.storage[0] > -0.001) {
          // cos(90 deg) is approx 0, checking for rotation matrix
          foundRotation = true;
        }
      }
      expect(foundRotation, isTrue, reason: 'Should find a Transform with rotation');
    });

    testWidgets('applies ColorFiltered when brightness is non-zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageCanvas(
              imagePath: '/path/to/image.jpg',
              heroTag: 'test-hero',
              isConverting: false,
              brightness: 0.5,
            ),
          ),
        ),
      );

      expect(find.byType(ColorFiltered), findsOneWidget);
    });

    testWidgets('does NOT apply ColorFiltered when brightness is zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageCanvas(
              imagePath: '/path/to/image.jpg',
              heroTag: 'test-hero',
              isConverting: false,
            ),
          ),
        ),
      );

      expect(find.byType(ColorFiltered), findsNothing);
    });
  });
}
