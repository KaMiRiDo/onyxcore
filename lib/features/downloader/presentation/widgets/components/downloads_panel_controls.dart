part of '../downloads_panel.dart';

@visibleForTesting
Future<void> exportListForTesting(State state) {
  return (state as _MediaDownloaderPanelState)._exportList();
}

@visibleForTesting
Future<void> updateListForTesting(State state) {
  return (state as _MediaDownloaderPanelState)._updateList();
}

@visibleForTesting
void showLocalToastForTesting(State state, String message) {
  (state as _MediaDownloaderPanelState)._showLocalToast(message);
}

@visibleForTesting
void showLogsForTesting(State state, MediaInfo item) {
  (state as _MediaDownloaderPanelState)._showLogs(item);
}

@visibleForTesting
void showUnsavedConfirmationForTesting(State state, VoidCallback action) {
  (state as _MediaDownloaderPanelState)._handleClearRequest(action);
}

@visibleForTesting
Future<void> importListForTesting(State state, [String? path]) {
  return (state as _MediaDownloaderPanelState)._importList(path);
}

@visibleForTesting
void setUrlControllerTextForTesting(State state, String text) {
  (state as _MediaDownloaderPanelState)._urlController.text = text;
}

@visibleForTesting
Future<void> analyzeUrlsForTesting(State state) {
  return (state as _MediaDownloaderPanelState)._analyzeUrls();
}

@visibleForTesting
DownloadsListCache getCacheForTesting(State state) {
  return (state as _MediaDownloaderPanelState)._cache;
}
