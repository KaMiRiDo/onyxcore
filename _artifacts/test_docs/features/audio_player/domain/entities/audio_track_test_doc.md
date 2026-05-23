# Audio Track Entity Test Document

### 1. Unit Test Plan Format
| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-AUD-TRACK-01 | audio_track.dart | AudioTrack constructor | create an AudioTrack with all required fields | Provide title, artist, path | Construct AudioTrack | verify title, artist, path are set correctly |
| U-AUD-TRACK-02 | audio_track.dart | AudioTrack constructor | create an AudioTrack with optional fields | Provide all fields including albumArtPath and duration | Construct AudioTrack | verify all fields including optional ones are set correctly |
| U-AUD-TRACK-03 | audio_track.dart | AudioTrack constructor | create an AudioTrack with null optional fields | Provide only required fields | Construct AudioTrack | verify albumArtPath is null, duration is null |
| U-AUD-TRACK-04 | audio_track.dart | Equatable props | consider two AudioTracks with same fields as equal | Create two identical AudioTracks | Compare with == operator | returns true |
| U-AUD-TRACK-05 | audio_track.dart | Equatable props | consider two AudioTracks with different titles as not equal | Create two AudioTracks with different titles | Compare with == operator | returns false |
| U-AUD-TRACK-06 | audio_track.dart | Equatable props | consider two AudioTracks with different paths as not equal | Create two AudioTracks with different paths | Compare with == operator | returns false |
| U-AUD-TRACK-07 | audio_track.dart | Equatable props | consider two AudioTracks with different optional fields as not equal | Create two AudioTracks — one with duration, one without | Compare with == operator | returns false |
| U-AUD-TRACK-08 | audio_track.dart | Equatable props | produce identical hashCodes for equal AudioTracks | Create two identical AudioTracks | Compare hashCode | hashCodes are equal |
| U-AUD-TRACK-09 | audio_track.dart | Equatable props | include all 5 fields in props list | Inspect AudioTrack.props | Read props | props list contains exactly [title, artist, path, albumArtPath, duration] |

### 2. Widget Test Plan Format
N/A - Pure Domain Entity
