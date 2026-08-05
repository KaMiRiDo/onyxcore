import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/properties_dialog.dart';

void main() {
  group('MediaInfo uploadDate parsing', () {
    test('parses timestamp correctly', () {
      final json = {
        'id': 'test1',
        'title': 'Test Title',
        'originalUrl': 'https://example.com/test1',
        'timestamp': 1684070400,
      };

      final info = MediaInfo.fromJson(json);
      expect(info.uploadDate, isNotNull);
      expect(
        info.uploadDate!.millisecondsSinceEpoch,
        equals(1684070400 * 1000),
      );
    });

    test('parses upload_date string YYYYMMDD correctly', () {
      final json = {
        'id': 'test2',
        'title': 'Test Title',
        'originalUrl': 'https://example.com/test2',
        'upload_date': '20230514',
      };

      final info = MediaInfo.fromJson(json);
      expect(info.uploadDate, isNotNull);
      expect(info.uploadDate!.year, equals(2023));
      expect(info.uploadDate!.month, equals(5));
      expect(info.uploadDate!.day, equals(14));
    });

    test('parses date string YYYY-MM-DD HH:MM:SS correctly', () {
      final json = {
        'id': 'test3',
        'title': 'Test Title',
        'originalUrl': 'https://example.com/test3',
        'date': '2023-05-14 12:34:56',
      };

      final info = MediaInfo.fromJson(json);
      expect(info.uploadDate, isNotNull);
      expect(info.uploadDate!.year, equals(2023));
      expect(info.uploadDate!.month, equals(5));
      expect(info.uploadDate!.day, equals(14));
      expect(info.uploadDate!.hour, equals(12));
      expect(info.uploadDate!.minute, equals(34));
    });

    test('parses taken_at_timestamp for Instagram items', () {
      final json = {
        'id': 'ig1',
        'title': 'Instagram Post',
        'originalUrl': 'https://instagram.com/p/abc',
        'taken_at_timestamp': 1684070400,
      };

      final info = MediaInfo.fromJson(json);
      expect(info.uploadDate, isNotNull);
      expect(info.uploadDate!.millisecondsSinceEpoch, equals(1684070400 * 1000));
    });

    test('parses created_at and post_date correctly', () {
      final json1 = {
        'id': 'tweet1',
        'title': 'Tweet',
        'originalUrl': 'https://x.com/user/status/123',
        'created_at': '2024-03-01T15:30:00Z',
      };
      final info1 = MediaInfo.fromJson(json1);
      expect(info1.uploadDate, isNotNull);
      expect(info1.uploadDate!.year, equals(2024));
      expect(info1.uploadDate!.month, equals(3));

      final json2 = {
        'id': 'reddit1',
        'title': 'Reddit Post',
        'originalUrl': 'https://reddit.com/r/pics/123',
        'post_date': '2024-04-10 08:20:00',
      };
      final info2 = MediaInfo.fromJson(json2);
      expect(info2.uploadDate, isNotNull);
      expect(info2.uploadDate!.year, equals(2024));
      expect(info2.uploadDate!.month, equals(4));
    });

    test('serializes and deserializes via toMap and fromMap', () {
      final date = DateTime(2023, 5, 14, 12, 30);
      final info = MediaInfo(
        id: 'test4',
        title: 'Test',
        originalUrl: 'https://example.com/test4',
        uploadDate: date,
      );

      final map = info.toMap();
      expect(map['uploadDate'], equals(date.toIso8601String()));

      final reconstructed = MediaInfo.fromMap(map);
      expect(reconstructed.uploadDate, equals(date));
    });

    test('MediaGroup exposes first non-null uploadDate from its items', () {
      final date = DateTime(2023, 5, 14);
      final group = MediaGroup(
        originalUrl: 'https://example.com/group',
        items: [
          const MediaInfo(
            id: 'item0_no_date',
            title: 'Item 0 No Date',
            originalUrl: 'https://example.com/item0',
          ),
          MediaInfo(
            id: 'item1',
            title: 'Item 1',
            originalUrl: 'https://example.com/item1',
            uploadDate: date,
          ),
        ],
      );

      expect(group.uploadDate, equals(date));
    });

    test('MediaGroup returns null uploadDate when items list is empty', () {
      const group = MediaGroup(
        originalUrl: 'https://example.com/empty',
        items: [],
      );

      expect(group.uploadDate, isNull);
    });

    test('parses millisecond timestamp (> 100,000,000,000) correctly', () {
      final json = {
        'id': 'testMs',
        'title': 'Test Ms',
        'originalUrl': 'https://example.com/testMs',
        'timestamp': 1684070400000,
      };

      final info = MediaInfo.fromJson(json);
      expect(info.uploadDate, isNotNull);
      expect(info.uploadDate!.millisecondsSinceEpoch, equals(1684070400000));
    });

    test('parses release_timestamp correctly', () {
      final json = {
        'id': 'testRelease',
        'title': 'Test Release',
        'originalUrl': 'https://example.com/testRelease',
        'release_timestamp': 1684070400,
      };

      final info = MediaInfo.fromJson(json);
      expect(info.uploadDate, isNotNull);
      expect(info.uploadDate!.millisecondsSinceEpoch, equals(1684070400000));
    });

    test('parses created_utc (Reddit float/int/string) correctly', () {
      final json1 = {
        'id': 'redditUtc1',
        'title': 'Reddit Post',
        'originalUrl': 'https://reddit.com/r/pics/123',
        'created_utc': 1684070400.0,
      };
      final info1 = MediaInfo.fromJson(json1);
      expect(info1.uploadDate, isNotNull);
      expect(info1.uploadDate!.millisecondsSinceEpoch, equals(1684070400 * 1000));

      final json2 = {
        'id': 'redditUtc2',
        'title': 'Reddit Post 2',
        'originalUrl': 'https://reddit.com/r/pics/456',
        'created_utc': '1684070400',
      };
      final info2 = MediaInfo.fromJson(json2);
      expect(info2.uploadDate, isNotNull);
      expect(info2.uploadDate!.millisecondsSinceEpoch, equals(1684070400 * 1000));
    });

    test('parses Twitter/X created_at format correctly', () {
      final json = {
        'id': 'tweetDate',
        'title': 'Tweet Post',
        'originalUrl': 'https://x.com/user/status/123',
        'created_at': 'Wed Apr 12 15:30:00 +0000 2023',
      };
      final info = MediaInfo.fromJson(json);
      expect(info.uploadDate, isNotNull);
      expect(info.uploadDate!.year, equals(2023));
      expect(info.uploadDate!.month, equals(4));
      expect(info.uploadDate!.day, equals(12));
      expect(info.uploadDate!.hour, equals(15));
      expect(info.uploadDate!.minute, equals(30));
    });

    test('parses Exif date format YYYY:MM:DD HH:MM:SS correctly', () {
      final json = {
        'id': 'exifDate',
        'title': 'Photo Post',
        'originalUrl': 'https://example.com/photo/123',
        'date': '2024:04:12 15:30:00',
      };
      final info = MediaInfo.fromJson(json);
      expect(info.uploadDate, isNotNull);
      expect(info.uploadDate!.year, equals(2024));
      expect(info.uploadDate!.month, equals(4));
      expect(info.uploadDate!.day, equals(12));
      expect(info.uploadDate!.hour, equals(15));
      expect(info.uploadDate!.minute, equals(30));
    });

    test('parses uploadDate from nested metadata structures (node, post, media)', () {
      final jsonNode = {
        'id': 'igNode',
        'title': 'Instagram Node Post',
        'originalUrl': 'https://instagram.com/p/abc',
        'node': {
          'taken_at_timestamp': 1684070400,
        },
      };
      final infoNode = MediaInfo.fromJson(jsonNode);
      expect(infoNode.uploadDate, isNotNull);
      expect(infoNode.uploadDate!.millisecondsSinceEpoch, equals(1684070400 * 1000));

      final jsonPost = {
        'id': 'postNested',
        'title': 'Nested Post',
        'originalUrl': 'https://example.com/post/1',
        'post': {
          'date': '2024-05-20 18:00:00',
        },
      };
      final infoPost = MediaInfo.fromJson(jsonPost);
      expect(infoPost.uploadDate, isNotNull);
      expect(infoPost.uploadDate!.year, equals(2024));
      expect(infoPost.uploadDate!.month, equals(5));
      expect(infoPost.uploadDate!.day, equals(20));
    });

    test('returns null gracefully on malformed date strings', () {
      final json = {
        'id': 'testBad',
        'title': 'Test Bad',
        'originalUrl': 'https://example.com/testBad',
        'upload_date': 'invalid_date_format',
      };

      final info = MediaInfo.fromJson(json);
      expect(info.uploadDate, isNull);
    });
  });

  group('PropertiesDialog Uploaded Date display', () {
    testWidgets('displays uploaded date and time when time is available', (tester) async {
      final date = DateTime(2023, 5, 14, 15, 45); // 3:45 PM
      final group = MediaGroup(
        originalUrl: 'https://example.com/group',
        items: [
          MediaInfo(
            id: 'item1',
            title: 'Video Title',
            originalUrl: 'https://example.com/item1',
            uploadDate: date,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertiesDialog(
              selectedItems: [group],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final formatted = DateFormat('MMM d, yyyy, h:mm a').format(date);
      expect(find.textContaining(formatted), findsOneWidget);
    });

    testWidgets('displays uploaded date (without time) when time is midnight (00:00:00)', (tester) async {
      final date = DateTime(2023, 5, 14);
      final item = MediaInfo(
        id: 'inner1',
        title: 'Inner Photo',
        originalUrl: 'https://example.com/photo',
        isVideo: false,
        uploadDate: date,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertiesDialog(
              selectedItems: [item],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final formatted = DateFormat('MMM d, yyyy').format(date);
      expect(find.textContaining(formatted), findsOneWidget);
    });

    testWidgets('displays Uploaded: Unknown when uploadDate is null', (tester) async {
      const item = MediaInfo(
        id: 'innerNoDate',
        title: 'Photo No Date',
        originalUrl: 'https://example.com/nodate',
        isVideo: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertiesDialog(
              selectedItems: [item],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Uploaded: Unknown'), findsOneWidget);
    });

    testWidgets('close cross button is positioned at top right corner of dialog card', (tester) async {
      const item = MediaInfo(
        id: 'itemClose',
        title: 'Short Title',
        originalUrl: 'https://example.com/close',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PropertiesDialog(
                selectedItems: const [item],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final closeBtnFinder = find.byType(IconButton);
      expect(closeBtnFinder, findsOneWidget);

      final closeBtnRect = tester.getRect(closeBtnFinder);
      // The dialog container has width 420, centered in 800 width (left=190, right=610)
      // The close button right edge should be near right edge (within 24px of dialog card edge, not center)
      expect(closeBtnRect.right, greaterThan(580));
    });
  });

  group('MediaInfo title fallback parsing', () {
    test('extracts title directly from Reddit comments URL when json title is missing', () {
      final info = MediaInfo.fromJson(
        {},
        originalUrl: 'https://www.reddit.com/r/InsideMollywood/comments/1example/looks_like_a_warning_sign_for_many/',
      );
      expect(info.title, 'Looks like a warning sign for many');
    });

    test('extracts subreddit name from subreddit URL when json title is missing', () {
      final info = MediaInfo.fromJson(
        {},
        originalUrl: 'https://www.reddit.com/r/InsideMollywood/',
      );
      expect(info.title, 'r/InsideMollywood');
    });

    test('extracts username from Reddit user profile URL when json title is missing', () {
      final info = MediaInfo.fromJson(
        {},
        originalUrl: 'https://www.reddit.com/user/Icy_Beach4427/',
      );
      expect(info.title, 'u/Icy_Beach4427');
    });

    test('prefers json title over URL slug when json title is present', () {
      final info = MediaInfo.fromJson(
        {'title': 'Looks like a warning sign for many 😅'},
        originalUrl: 'https://www.reddit.com/r/InsideMollywood/comments/1example/looks_like_a_warning_sign_for_many/',
      );
      expect(info.title, 'Looks like a warning sign for many 😅');
    });
  });
}
