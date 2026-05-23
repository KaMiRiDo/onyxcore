# Audio Queue Isolate Test Document

### 1. Unit Test Plan Format
| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-AUD-ISOLATE-01 | audio_queue_isolate.dart | processAudioQueueIsolate | filter out non-audio file items from input list | Provide list with audio, video, image, and document FileItems | Call processAudioQueueIsolate({'items': [...], 'showHidden': true}) | Returns only audio FileItems |
| U-AUD-ISOLATE-02 | audio_queue_isolate.dart | processAudioQueueIsolate | include folders that contain audio files | Provide list with a folder containing 3 audio files (use MemoryFileSystem) | Call processAudioQueueIsolate | Returns folder FileItem with itemCount=3 |
| U-AUD-ISOLATE-03 | audio_queue_isolate.dart | processAudioQueueIsolate | exclude folders that contain zero audio files | Provide list with a folder containing only image files | Call processAudioQueueIsolate | Result does not contain the folder |
| U-AUD-ISOLATE-04 | audio_queue_isolate.dart | processAudioQueueIsolate | hide hidden files when showHidden is false | Provide list with items ".hidden_song.mp3" and "visible_song.mp3", showHidden=false | Call processAudioQueueIsolate | Returns only "visible_song.mp3" |
| U-AUD-ISOLATE-05 | audio_queue_isolate.dart | processAudioQueueIsolate | show hidden files when showHidden is true | Provide list with items ".hidden_song.mp3" and "visible_song.mp3", showHidden=true | Call processAudioQueueIsolate | Returns both items |
| U-AUD-ISOLATE-06 | audio_queue_isolate.dart | processAudioQueueIsolate | skip hidden sub-files in folder count when showHidden is false | Provide folder containing ".hidden.mp3" and "visible.mp3", showHidden=false | Call processAudioQueueIsolate | Folder's itemCount=1 (only "visible.mp3") |
| U-AUD-ISOLATE-07 | audio_queue_isolate.dart | processAudioQueueIsolate | count hidden sub-files in folder count when showHidden is true | Provide folder containing ".hidden.mp3" and "visible.mp3", showHidden=true | Call processAudioQueueIsolate | Folder's itemCount=2 |
| U-AUD-ISOLATE-08 | audio_queue_isolate.dart | processAudioQueueIsolate | return empty list when all items are non-audio and non-folder | Provide list of video and image FileItems only | Call processAudioQueueIsolate | Returns empty list |
| U-AUD-ISOLATE-09 | audio_queue_isolate.dart | processAudioQueueIsolate | return empty list when input items list is empty | Provide empty items list | Call processAudioQueueIsolate | Returns empty list |
| U-AUD-ISOLATE-10 | audio_queue_isolate.dart | processAudioQueueIsolate | handle non-existent folder paths gracefully | Provide a folder FileItem whose directory doesn't exist on disk | Call processAudioQueueIsolate | Folder is excluded from result, no crash |
| U-AUD-ISOLATE-11 | audio_queue_isolate.dart | processAudioQueueIsolate | only scan one level deep (not recursive) | Provide folder with nested subfolder containing audio files | Call processAudioQueueIsolate | Folder's itemCount only counts direct children, not nested |
| U-AUD-ISOLATE-12 | audio_queue_isolate.dart | processAudioQueueIsolate | preserve original order of audio items | Provide list [audio_c.mp3, audio_a.mp3, audio_b.mp3] | Call processAudioQueueIsolate | Returns items in same input order |
| U-AUD-ISOLATE-13 | audio_queue_isolate.dart | processAudioQueueIsolate | correctly deserialize FileItem from JSON map | Provide items as List of JSON maps with all FileItem fields | Call processAudioQueueIsolate | FileItems are correctly reconstructed from JSON |
| U-AUD-ISOLATE-14 | audio_queue_isolate.dart | processAudioQueueIsolate | handle folder containing mixed audio and non-audio files | Provide folder with 2 audio + 3 video files | Call processAudioQueueIsolate | Folder's itemCount=2 |
| U-AUD-ISOLATE-15 | audio_queue_isolate.dart | processAudioQueueIsolate | handle permission-denied folder gracefully | Provide a folder FileItem whose directory throws PermissionException on listSync | Call processAudioQueueIsolate | Folder is excluded from result, no crash |

### 2. Widget Test Plan Format
N/A - Pure Domain Logic (Isolate Function)
