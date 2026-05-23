# Audio Properties Dialog Test Document

### 1. Unit Test Plan Format
N/A - UI and Integration Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-PROP-01 | audio_properties_dialog.dart | AudioPropertiesDialog | show loading spinner during data fetch | Mock AudioMetadataUtils with delayed response | Open dialog | verify CircularProgressIndicator is displayed with AppColors.violet color |
| W-AUD-PROP-02 | audio_properties_dialog.dart | AudioPropertiesDialog | load and display all metadata sections | Mock FileStat, AudioMetadataUtils tags (title, artist, album, genre) and properties (duration, bitrate, sampleRate) | Open dialog, wait for load | verify METADATA, AUDIO FORMAT, FILE SYSTEM section headers displayed; verify Title, Artist, Album, Genre, Duration, Bitrate, Sample Rate, File Name, Location, Size, Added Time, Updated Time rows |
| W-AUD-PROP-03 | audio_properties_dialog.dart | AudioPropertiesDialog | display "Unknown" for missing tag fields | Mock AudioMetadataUtils returning null tags | Open dialog | verify Title, Artist, Album, Genre all display "Unknown" |
| W-AUD-PROP-04 | audio_properties_dialog.dart | AudioPropertiesDialog | display "Unknown" for missing audio properties | Mock AudioMetadataUtils.getProperties returning all "Unknown" | Open dialog | verify Duration, Bitrate, Sample Rate all display "Unknown" |
| W-AUD-PROP-05 | audio_properties_dialog.dart | AudioPropertiesDialog | close dialog on escape key | Render dialog | Press Escape key | verify dialog is popped |
| W-AUD-PROP-06 | audio_properties_dialog.dart | AudioPropertiesDialog | close dialog on close icon button | Render dialog | Tap close IconButton (Icons.close) | verify dialog is popped |
| W-AUD-PROP-07 | audio_properties_dialog.dart | AudioPropertiesDialog | close dialog on footer Close button | Render dialog | Tap ElevatedButton "Close" in footer | verify dialog is popped |
| W-AUD-PROP-08 | audio_properties_dialog.dart | AudioPropertiesDialog | format bytes correctly for bytes | Render dialog with FileStat size 500 | Open dialog | verify size is displayed as "500 B" |
| W-AUD-PROP-09 | audio_properties_dialog.dart | AudioPropertiesDialog | format bytes correctly for kilobytes | Render dialog with FileStat size 2048 | Open dialog | verify size is displayed as "2.0 KB" |
| W-AUD-PROP-10 | audio_properties_dialog.dart | AudioPropertiesDialog | format bytes correctly for megabytes | Render dialog with FileStat size 1048576 | Open dialog | verify size is displayed as "1.0 MB" |
| W-AUD-PROP-11 | audio_properties_dialog.dart | AudioPropertiesDialog | format bytes correctly for gigabytes | Render dialog with FileStat size 1073741824 | Open dialog | verify size is displayed as "1.0 GB" |
| W-AUD-PROP-12 | audio_properties_dialog.dart | AudioPropertiesDialog | display header with "AUDIO INFORMATION" title | Render dialog | Open dialog | Finds Text "AUDIO INFORMATION" with letterSpacing 2.0, fontSize 14, fontWeight w800 |
| W-AUD-PROP-13 | audio_properties_dialog.dart | AudioPropertiesDialog | display section headers in violet color | Render dialog, wait for load | Render view | verify section headers (METADATA, AUDIO FORMAT, FILE SYSTEM) use AppColors.violet with 0.8 opacity |
| W-AUD-PROP-14 | audio_properties_dialog.dart | AudioPropertiesDialog | make location path selectable (SelectableText) | Render dialog, wait for load | Open dialog | verify "Location" row value uses SelectableText widget |
| W-AUD-PROP-15 | audio_properties_dialog.dart | AudioPropertiesDialog | display filename (basename) in File Name row | Path is "/home/user/music/song.mp3" | Open dialog | verify File Name row shows "song.mp3" |
| W-AUD-PROP-16 | audio_properties_dialog.dart | AudioPropertiesDialog | display full path in Location row | Path is "/home/user/music/song.mp3" | Open dialog | verify Location row shows full path |
| W-AUD-PROP-17 | audio_properties_dialog.dart | AudioPropertiesDialog | format dates as 'yyyy-MM-dd HH:mm' | Mock FileStat with specific changed and modified dates | Open dialog | verify Added Time and Updated Time match expected formatted dates |
| W-AUD-PROP-18 | audio_properties_dialog.dart | AudioPropertiesDialog | render dialog container with correct styling | Render dialog | Open dialog | verify Container width=500, borderRadius=20, dark background color |
| W-AUD-PROP-19 | audio_properties_dialog.dart | AudioPropertiesDialog | render gradient close button in footer | Render dialog | Open dialog | verify ElevatedButton inside Container with AppTheme.primaryGradient |
| W-AUD-PROP-20 | audio_properties_dialog.dart | AudioPropertiesDialog | handle exception during property loading gracefully | Mock File.statSync to throw FileSystemException | Open dialog | verify dialog renders without crash, shows data that was loaded before error |
| W-AUD-PROP-21 | audio_properties_dialog.dart | AudioPropertiesDialog | ignore non-KeyDown/KeyRepeat events | Send KeyUpEvent for Escape | Send key event | verify dialog is NOT popped |
| W-AUD-PROP-22 | audio_properties_dialog.dart | AudioPropertiesDialog.show | open dialog with correct barrier color | Call AudioPropertiesDialog.show(context, path) | Show dialog | verify dialog opened with barrierColor black 70% opacity |
| W-AUD-PROP-23 | audio_properties_dialog.dart | AudioPropertiesDialog | use autofocus on wrapping Focus widget | Render dialog | Open dialog | verify Focus widget has autofocus=true |
| W-AUD-PROP-24 | audio_properties_dialog.dart | AudioPropertiesDialog | render property labels at 120px fixed width | Render dialog | Open dialog | verify label SizedBox width=120 |
