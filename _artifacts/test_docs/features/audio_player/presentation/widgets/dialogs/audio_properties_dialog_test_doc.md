# Audio Properties Dialog Test Document

### 1. Unit Test Plan Format
N/A - UI and Integration Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-PROP-01 | audio_properties_dialog.dart | AudioPropertiesDialog | load and display file properties | Mock FileStat, AudioMetadataUtils tags and props | Open dialog | verify loading state -> displays metadata, format, filesystem data |
| W-AUD-PROP-02 | audio_properties_dialog.dart | AudioPropertiesDialog | handle missing metadata gracefully | Mock AudioMetadataUtils returning null tags | Open dialog | displays "Unknown" for missing fields |
| W-AUD-PROP-03 | audio_properties_dialog.dart | AudioPropertiesDialog | close dialog on escape key | Render dialog | Press Escape key | verify dialog is popped |
| W-AUD-PROP-04 | audio_properties_dialog.dart | AudioPropertiesDialog | format bytes correctly | Render dialog with FileStat size 1048576 | Open dialog | verify size is displayed as "1.0 MB" |
