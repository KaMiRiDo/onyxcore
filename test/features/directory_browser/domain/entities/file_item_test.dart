import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  group('FileItem', () {
    final tModified = DateTime(2023);
    final tItem = FileItem(
      path: '/path/to/doc.pdf',
      name: 'doc.pdf',
      type: FileItemType.document,
      modified: tModified,
      sizeBytes: 1024,
      thumbnailPath: '/path/thumb.jpg',
      imageAspectRatio: 1.5,
      isExecutable: true,
      hasWritePermission: false,
    );

    test('supports value equality (Equatable)', () {
      final tItem2 = FileItem(
        path: '/path/to/doc.pdf',
        name: 'doc.pdf',
        type: FileItemType.document,
        modified: tModified,
        sizeBytes: 1024,
        thumbnailPath: '/path/thumb.jpg',
        imageAspectRatio: 1.5,
        isExecutable: true,
        hasWritePermission: false,
      );

      final tItem3 = FileItem(
        path: '/path/to/other.pdf',
        name: 'other.pdf',
        type: FileItemType.document,
        modified: tModified,
      );

      expect(tItem, equals(tItem2));
      expect(tItem, isNot(equals(tItem3)));
    });

    test('copyWith should update fields correctly', () {
      final newModified = DateTime(2024);
      final updated = tItem.copyWith(
        path: '/new/path.pdf',
        name: 'path.pdf',
        type: FileItemType.other,
        modified: newModified,
        sizeBytes: 2048,
        thumbnailPath: '/new/thumb.jpg',
        imageAspectRatio: 2,
        itemCount: 5,
        isExecutable: false,
        hasWritePermission: true,
      );

      expect(updated.path, '/new/path.pdf');
      expect(updated.name, 'path.pdf');
      expect(updated.type, FileItemType.other);
      expect(updated.modified, newModified);
      expect(updated.sizeBytes, 2048);
      expect(updated.thumbnailPath, '/new/thumb.jpg');
      expect(updated.imageAspectRatio, 2.0);
      expect(updated.itemCount, 5);
      expect(updated.isExecutable, false);
      expect(updated.hasWritePermission, true);
    });

    test('copyWith should retain old values if null is passed', () {
      final updated = tItem.copyWith();

      expect(updated.path, tItem.path);
      expect(updated.name, tItem.name);
      expect(updated.type, tItem.type);
      expect(updated.modified, tItem.modified);
      expect(updated.sizeBytes, tItem.sizeBytes);
      expect(updated.thumbnailPath, tItem.thumbnailPath);
      expect(updated.imageAspectRatio, tItem.imageAspectRatio);
      expect(updated.itemCount, tItem.itemCount);
      expect(updated.isExecutable, tItem.isExecutable);
      expect(updated.hasWritePermission, tItem.hasWritePermission);
    });

    test('toJson and fromJson should work correctly', () {
      final json = tItem.toJson();
      
      expect(json['path'], '/path/to/doc.pdf');
      expect(json['name'], 'doc.pdf');
      expect(json['type'], FileItemType.document.index);
      expect(json['modified'], tModified.millisecondsSinceEpoch);
      expect(json['sizeBytes'], 1024);
      expect(json['thumbnailPath'], '/path/thumb.jpg');
      expect(json['imageAspectRatio'], 1.5);
      expect(json['itemCount'], isNull);
      expect(json['isExecutable'], true);
      expect(json['hasWritePermission'], false);

      final fromJsonItem = FileItem.fromJson(json);
      expect(fromJsonItem, equals(tItem));
    });

    test('fromJson should use defaults if missing optional fields', () {
      final minimalJson = {
        'path': '/min',
        'name': 'min',
        'type': FileItemType.folder.index,
        'modified': tModified.millisecondsSinceEpoch,
      };

      final fromJsonItem = FileItem.fromJson(minimalJson);
      
      expect(fromJsonItem.path, '/min');
      expect(fromJsonItem.name, 'min');
      expect(fromJsonItem.type, FileItemType.folder);
      expect(fromJsonItem.modified, tModified);
      expect(fromJsonItem.sizeBytes, isNull);
      expect(fromJsonItem.thumbnailPath, isNull);
      expect(fromJsonItem.imageAspectRatio, isNull);
      expect(fromJsonItem.itemCount, isNull);
      expect(fromJsonItem.isExecutable, false);
      expect(fromJsonItem.hasWritePermission, true);
    });
  });
}
