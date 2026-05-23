# Audio Tag Editor Dialog Test Document

### 1. Unit Test Plan Format
N/A - UI and Integration Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-TAG-01 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | load initial tags for a single file | Mock AudioMetadataUtils.readTags | Open dialog for 1 file | verify text controllers populated with tag data |
| W-AUD-TAG-02 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | compute common prefix for bulk rename | Provide 3 files sharing prefix "Song_" | Open dialog for 3 files | verify bulkRenameController contains "Song_" |
| W-AUD-TAG-03 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | pick and prepare new cover art | Mock file picker returning image | Tap camera icon | verify image processed, newCoverArt state updated |
| W-AUD-TAG-04 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | clear cover art | Load dialog with existing cover art | Tap remove cover icon | verify clearCoverArt state is true, UI updates |
| W-AUD-TAG-05 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | save updated tags for a single file | Mock AudioMetadataUtils.writeTags | Edit title, tap Enter/Save | verify writeTags called with new title, task added to TaskProvider |
| W-AUD-TAG-06 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | rename single file if title changed | Mock File.rename | Change title in dialog, save | verify File.rename called with new title |
| W-AUD-TAG-07 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | bulk rename with prefix mode | Select 3 files, prefix mode, enter "New_" | Save | verify 3 files renamed with "New_" prefix |
| W-AUD-TAG-08 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | bulk rename with base name mode | Select 3 files, base name mode, enter "Base" | Save | verify 3 files renamed to "Base_1", "Base_2", "Base_3" |
| W-AUD-TAG-09 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | update audio provider cache instantly on save | Mock tags and providers | Save tag changes | verify audioTagsOverridesProvider updated with new tag |
| W-AUD-TAG-10 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | handle file rename callback | Mock onRename callback | Rename file via title change | verify onRename callback executed with old and new paths |
| W-AUD-TAG-11 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | delete thumbnails when cover art changes | Change cover art | Save tag changes | verify thumbnail file deleted and cleared from queue providers |
| W-AUD-TAG-12 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | clear global image cache on save | Change cover art | Save tag changes | verify PaintingBinding.instance.imageCache.clear() called |
| W-AUD-TAG-13 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | run save task sequentially to avoid race conditions | Select 5 files | Save tag changes | verify Future.wait uses concurrency of 1 |
| W-AUD-TAG-14 | audio_tag_editor_dialog.dart | AudioTagEditorDialog | abort save if task is cancelled | Mock task cancellation during save loop | Cancel task via UI | verify processing loop breaks |
