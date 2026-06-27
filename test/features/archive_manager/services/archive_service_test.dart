import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/archive_manager/services/archive_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late File sourceFile1;
  late File sourceFile2;
  late String targetArchive;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('archive_service_test');
    
    sourceFile1 = File(p.join(tempDir.path, 'file1.txt'));
    await sourceFile1.writeAsString('Hello World 1');
    
    sourceFile2 = File(p.join(tempDir.path, 'file2.txt'));
    await sourceFile2.writeAsString('Hello World 2');
    
    targetArchive = p.join(tempDir.path, 'test_archive.zip');
  });

  tearDown(() async {
    ArchiveService.killZombies();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ArchiveService', () {
    test('compresses and extracts files successfully', () async {
      final sourcePaths = [sourceFile1.path, sourceFile2.path];
      
      var lastProgress = 0.0;
      final logs = <String>[];
      
      await ArchiveService.compress(
        sourcePaths: sourcePaths,
        targetArchive: targetArchive,
        onProgress: (p) => lastProgress = p,
        onLog: logs.add,
      );
      
      expect(await File(targetArchive).exists(), isTrue);
      
      final extractDir = p.join(tempDir.path, 'extracted');
      await Directory(extractDir).create();
      
      await ArchiveService.extract(
        archivePath: targetArchive,
        outputDir: extractDir,
        onProgress: (p) => lastProgress = p,
        onLog: logs.add,
      );
      
      final extractedFile1 = File(p.join(extractDir, 'file1.txt'));
      final extractedFile2 = File(p.join(extractDir, 'file2.txt'));
      
      expect(await extractedFile1.exists(), isTrue);
      expect(await extractedFile2.exists(), isTrue);
      
      expect(await extractedFile1.readAsString(), 'Hello World 1');
      
      expect(lastProgress, isNotNull); // Used variable
    });

    test('isEncrypted returns false for non-encrypted archive', () async {
      await ArchiveService.compress(
        sourcePaths: [sourceFile1.path],
        targetArchive: targetArchive,
      );
      
      final isEncrypted = await ArchiveService.isEncrypted(targetArchive);
      expect(isEncrypted, isFalse);
    });

    test('isEncrypted returns true for encrypted archive', () async {
      final encryptedArchive = p.join(tempDir.path, 'test_encrypted.zip');
      
      await ArchiveService.compress(
        sourcePaths: [sourceFile1.path],
        targetArchive: encryptedArchive,
        password: 'testpassword',
      );
      
      final isEncrypted = await ArchiveService.isEncrypted(encryptedArchive);
      expect(isEncrypted, isTrue);
    });
    
    test('extract fails with wrong password on encrypted archive', () async {
      final encryptedArchive = p.join(tempDir.path, 'test_encrypted.7z');
      
      await ArchiveService.compress(
        sourcePaths: [sourceFile1.path],
        targetArchive: encryptedArchive,
        password: 'testpassword',
      );
      
      final extractDir = p.join(tempDir.path, 'extracted_encrypted');
      await Directory(extractDir).create();
      
      expect(
        () => ArchiveService.extract(
          archivePath: encryptedArchive,
          outputDir: extractDir,
          password: 'wrongpassword',
        ),
        throwsException,
      );
    });
  });
}
