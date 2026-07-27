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

      expect(image.image, isA<ResizeImage>());
      final resizeImage = image.image as ResizeImage;
      expect(resizeImage.width, equals(1920));
      expect(resizeImage.height, equals(1920));
      expect(resizeImage.policy, equals(ResizeImagePolicy.fit));
    });

    testWidgets('renders local raster image with low filter quality during interaction',
        (tester) async {
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

    testWidgets('renders network raster image using NetworkImage provider', (tester) async {
      // ImageCanvas selects NetworkImage for http(s) URLs.
      // We verify the widget-tree structure synchronously — no actual HTTP request
      // is made because the image provider is only resolved when the Image widget
      // first tries to decode, which does not happen in this synchronous pump.
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

      // Widget tree should contain an Image (low-res slot before 300 ms timer fires)
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final image = tester.widget<Image>(imageFinder);
      expect(image.fit, equals(BoxFit.contain));
      expect(image.filterQuality, equals(FilterQuality.high));

      // Provider must be a ResizeImage wrapping a NetworkImage
      expect(image.image, isA<ResizeImage>());
      final resizeImage = image.image as ResizeImage;
      expect(resizeImage.imageProvider, isA<NetworkImage>());
      expect(resizeImage.width, equals(1920));
      expect(resizeImage.height, equals(1920));
      expect(resizeImage.policy, equals(ResizeImagePolicy.fit));
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

    testWidgets('progressively loads high resolution image after 300ms delay',
        (tester) async {
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

      // Initially, only the resized image should be present
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, equals(1));
      expect(images.first.image, isA<ResizeImage>());

      // Wait for the 300ms timer
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(); // Allow state to update

      // Now, both images should be present in a Stack (low-res and high-res)
      final allImages = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(allImages.length, equals(2));

      // Bottom layer should be the low-res
      expect(allImages[0].image, isA<ResizeImage>());

      // Top layer should be the full-res (not a ResizeImage)
      expect(allImages[1].image, isNot(isA<ResizeImage>()));
    });
  });
}
