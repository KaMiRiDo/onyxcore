import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    final result = await Process.run('lsblk', ['--json', '-o', 'NAME,MOUNTPOINT,SIZE,FSUSED,FSSIZE,TYPE,LABEL,MODEL']);
    print('Exit code: ${result.exitCode}');
    if (result.exitCode != 0) return;

    final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    print('Devices found: ${data['blockdevices']?.length}');

    void parseDevices(List<dynamic> list) {
      for (var item in list) {
        final mountpoint = item['mountpoint'] as String?;
        print('Checking ${item['name']} mounted at $mountpoint');
        if (mountpoint != null) {
          print('  Filter checks:');
          print('    !/snap: ${!mountpoint.startsWith('/snap')}');
          print('    !/boot: ${!mountpoint.startsWith('/boot')}');
          print('    !swap: ${mountpoint != '[SWAP]'}');
          print('    !root: ${mountpoint != '/'}');
        }

        if (item['children'] != null) {
          parseDevices(item['children'] as List<dynamic>);
        }
      }
    }

    if (data['blockdevices'] != null) {
      parseDevices(data['blockdevices'] as List<dynamic>);
    }
  } catch (e) {
    print('Error: $e');
  }
}
