import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) return;
  final lines = file.readAsLinesSync();
  
  String currentFile = '';
  int totalLines = 0;
  int hitLines = 0;
  List<int> missedLines = [];
  
  for (var line in lines) {
    if (line.startsWith('SF:')) {
      if (currentFile.isNotEmpty && (currentFile.contains('markdown_preview_widget.dart') || currentFile.contains('line_numbers_painter.dart'))) {
        print('File: $currentFile');
        print('Coverage: ${(hitLines / totalLines * 100).toStringAsFixed(2)}%');
        print('Missed Lines: $missedLines\n');
      }
      currentFile = line.substring(3);
      totalLines = 0;
      hitLines = 0;
      missedLines = [];
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final lineNum = int.parse(parts[0]);
      final hits = int.parse(parts[1]);
      totalLines++;
      if (hits > 0) {
        hitLines++;
      } else {
        missedLines.add(lineNum);
      }
    }
  }
  
  if (currentFile.isNotEmpty && (currentFile.contains('markdown_preview_widget.dart') || currentFile.contains('line_numbers_painter.dart'))) {
    print('File: $currentFile');
    print('Coverage: ${(hitLines / totalLines * 100).toStringAsFixed(2)}%');
    print('Missed Lines: $missedLines\n');
  }
}
