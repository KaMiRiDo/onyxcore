import 'package:media_kit/media_kit.dart';
import 'dart:io';

void main() async {
  MediaKit.ensureInitialized();
  final player = Player();
  final platform = player.platform as dynamic;

  platform.setProperty('audio-files', 'https://file-examples.com/storage/fe398dbd07669d587c65db5/2017/11/file_example_MP3_700KB.mp3');
  platform.setProperty('audio-file', 'https://file-examples.com/storage/fe398dbd07669d587c65db5/2017/11/file_example_MP3_700KB.mp3');

  await player.open(Media('https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4'));

  player.stream.position.listen((pos) {
    print('Position: $pos');
  });

  player.stream.audioParams.listen((params) {
    print('Audio Params: $params');
  });

  await Future.delayed(Duration(seconds: 10));
  exit(0);
}
