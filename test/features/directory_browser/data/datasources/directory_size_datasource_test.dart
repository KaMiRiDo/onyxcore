import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/directory_size_datasource.dart';

void main() {
  late DirectorySizeDatasource datasource;
  late Directory tempDir;

  setUp(() {
    datasource = DirectorySizeDatasource();
    tempDir = Directory.systemTemp.createTempSync('onyx_test_sizes_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('getDirectorySizes should return sizes for multiple directories', () async {
    final dir1 = Directory('${tempDir.path}/dir1')..createSync();
    final dir2 = Directory('${tempDir.path}/dir2')..createSync();
    
    File('${dir1.path}/file1.txt').writeAsStringSync('12345'); // 5 bytes
    File('${dir2.path}/file2.txt').writeAsStringSync('1234567890'); // 10 bytes

    final sizes = await datasource.getDirectorySizes([dir1.path, dir2.path]);
    
    expect(sizes, isNotNull);
    expect(sizes[dir1.path], 5);
    expect(sizes[dir2.path], 10);
  });
}
