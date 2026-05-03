import 'dart:convert';
import 'dart:io';

void main() async {
  final result = await Process.run('lsblk', [
    '--json', '--bytes', '-p',
    '-o', 'NAME,MOUNTPOINT,SIZE,FSUSED,FSSIZE,TYPE,LABEL,MODEL,RM,FSTYPE'
  ]);
  final data = jsonDecode(result.stdout as String);
  
  void parse(List<dynamic> list) {
    for (var item in list) {
      final mountpoint = item['mountpoint'] as String?;
      final fstype = item['fstype']?.toString() ?? '';
      final isRemovable = (item['rm'] == true || item['rm'] == 1 || item['rm'] == "1");

      final mp = mountpoint?.trim() ?? '';
      
      final isExt = fstype.startsWith('ext');
      final isMounted = mp.isNotEmpty;
      final isRemovableDrive = isRemovable || mp.startsWith('/media') || mp.startsWith('/run/media');

      if (!mp.startsWith('/snap') && mp != '[SWAP]' && fstype != 'swap') {
        if (isMounted || isExt || isRemovableDrive) {
           print('ADDED: ${item['name']} - mp: "$mp" - fstype: $fstype - rm: $isRemovable');
        }
      }
      if (item['children'] != null) {
        parse(item['children']);
      }
    }
  }
  
  parse(data['blockdevices']);
}
