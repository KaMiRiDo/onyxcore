import 'dart:convert';
import 'dart:io';

void main() async {
  final result = await Process.run('lsblk', ['--json', '-o', 'NAME,MOUNTPOINT,SIZE,FSUSED,FSSIZE,TYPE,LABEL,MODEL']);
  final data = jsonDecode(result.stdout as String);
  
  void printItems(List<dynamic> list, int indent) {
    for (var item in list) {
      print('${'  ' * indent}${item['name']} - ${item['mountpoint']} - ${item['label']}');
      if (item['children'] != null) {
        printItems(item['children'] as List<dynamic>, indent + 1);
      }
    }
  }

  printItems(data['blockdevices'], 0);
}
