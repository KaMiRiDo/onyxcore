# OnyxCore — Recommended Updates & Roadmap

> Strategic improvements organized by module priority. Each section lists features and architectural updates that would enhance the application.

---

## 1. Core Architecture

### 1.1 Isolate Worker Pool
- Replace per-operation `Isolate.run` calls with a **centralized IsolatePool** (2-4 workers)
- Reuse isolates across copy/move/delete/size-calculation operations
- Add graceful shutdown and timeout handling
- Priority: **High** — prevents resource exhaustion during batch operations

### 1.2 Error Boundary System
- Implement global error handler for uncaught isolate/async exceptions
- Surface silent failures to UI with retry options
- Add crash recovery for stuck background tasks
- Priority: **High**

### 1.3 Plugin Architecture
- Abstract file operations behind a plugin interface for extensibility
- Enable third-party integrations (cloud storage backends, archive handlers)
- Priority: **Low** — future extensibility

### 1.4 Logging & Diagnostics
- Add structured logging with log levels (debug/info/warn/error)
- Optional log-to-file for user bug reports
- Performance profiling hooks for render/IO bottlenecks
- Priority: **Medium**

---

## 2. Directory Browser

### 2.1 List View Mode
- Add a **list/detail view** toggle alongside the existing grid view
- Show columns: Name, Size, Type, Date Modified, Permissions
- Sortable column headers
- Priority: **High** — standard file manager expectation

### 2.2 Dual Pane Mode
- Split the browser into two independent directory panes
- Drag-and-drop between panes for copy/move
- Priority: **Medium**

### 2.3 Favorites / Bookmarks
- Allow users to **pin custom folders** to the sidebar
- Drag-and-drop reordering of pinned items
- Already partially modeled in `AppSettings.pinnedFolders`
- Priority: **High**

### 2.4 Breadcrumb Dropdown
- Add a **dropdown arrow** on each breadcrumb segment showing sibling folders
- Enable quick lateral navigation without going back
- Priority: **Medium**

### 2.5 Directory Size Column
- Show folder sizes inline (lazy-computed via isolate)
- Cache results in `MetadataCache`
- Priority: **Medium**

### 2.6 File Preview Tooltips
- Show hover tooltips with file metadata (size, date, dimensions for images)
- Small thumbnail preview for image files on hover
- Priority: **Low**

### 2.7 Undo/Redo for File Operations
- Implement an undo stack for move/rename/delete operations
- "Undo" snackbar after destructive actions (like Gmail's undo send)
- Priority: **Medium**

### 2.8 Batch Compress
- Implement the "Compress..." context menu item (currently placeholder)
- Support zip/tar.gz/7z creation
- Priority: **Medium**

### 2.9 Virtual Folders
- Implement **Recent files** (currently `virtual:recent` route exists but may need data source)
- Implement **Starred/Favorites** virtual folder
- Priority: **Medium**

### 2.10 Terminal Integration
- Embedded terminal panel (like VS Code's integrated terminal)
- Currently only "Open in Terminal" launches external gnome-terminal
- Priority: **Low**

---

## 3. Image Viewer

### 3.1 Thumbnail Strip
- Add a horizontal **thumbnail filmstrip** at the bottom for quick navigation
- Highlight current image; click to jump
- Priority: **Medium**

### 3.2 Slideshow Mode
- Auto-advance through images with configurable interval
- Transition animations (fade, slide)
- Priority: **Low**

### 3.3 Advanced Editor Features
- **Color/Saturation adjustments** (extend ffmpeg pipeline)
- **Resize/Scale** tool
- **Filters** (grayscale, sepia, sharpen, blur)
- **Undo/Redo** stack for edit operations
- Priority: **Medium**

### 3.4 RAW Image Support
- Detect and render RAW camera formats (CR2, NEF, ARW) via dcraw/libraw
- Priority: **Low**

### 3.5 Image Comparison
- Side-by-side or overlay comparison mode for similar images
- Priority: **Low**

### 3.6 Album Art Extraction
- Extract embedded thumbnails from image EXIF for faster grid loading
- Priority: **Medium** — performance improvement

---

## 4. Video Player

### 4.1 Chapter Support
- Parse and display chapter markers on the seek bar
- Chapter list in a side panel
- Priority: **Medium**

### 4.2 A-B Loop
- Set loop points A and B for repeated playback of a segment
- Priority: **Low**

### 4.3 Video Filters
- Real-time video filters (brightness, contrast, hue) via media_kit/mpv
- Priority: **Low**

### 4.4 Picture-in-Picture
- Floating mini-player overlay while browsing files
- Priority: **Medium**

### 4.5 Thumbnail Preview on Seek
- Show frame thumbnails when hovering over the progress bar
- Priority: **Medium** — significant UX improvement

### 4.6 Keyboard Shortcut Overlay
- Show a `?` help overlay listing all keyboard shortcuts
- Priority: **Low**

### 4.7 Cast/Stream Support
- DLNA/Chromecast streaming capability
- Priority: **Low** — future feature

### 4.8 Video Editing
- Implement the "Edit Video" button (currently TODO placeholder)
- Basic trim, cut, concatenate via ffmpeg
- Priority: **Medium**

---

## 5. Audio Player

### 5.1 Album Art Extraction
- Extract embedded album art from audio files (ID3 tags, Vorbis comments)
- Display in hero player and playlist tiles
- Priority: **High** — currently shows placeholder icon

### 5.2 Metadata Extraction
- Parse artist, album, track number, genre from audio metadata
- Replace hardcoded "Unknown Artist" and "3:42" duration
- Priority: **High** — core UX gap

### 5.3 Real Waveform Analysis
- Generate actual waveform data from audio file (via ffmpeg or audiowaveform CLI)
- Replace the current pseudo-random procedural waveform
- Priority: **Medium**

### 5.4 Equalizer
- Visual equalizer with preset profiles
- Priority: **Low**

### 5.5 Gapless Playback
- Ensure seamless transitions between tracks (pre-buffer next track)
- Priority: **Medium**

### 5.6 Mini Player
- Persistent bottom mini-player bar when navigating away from audio view
- Priority: **Medium**

### 5.7 Queue Management
- Drag-and-drop reordering of the playlist
- Add/remove individual tracks from queue
- Priority: **Medium**

---

## 6. Document Viewer

### 6.1 PDF Viewer
- Implement PDF rendering (currently shows placeholder)
- Use `pdfium` or `pdf_render` package
- Priority: **High** — PDF is a very common format

### 6.2 Syntax Highlighting
- Add proper syntax highlighting to code blocks in markdown viewer
- Use `highlight` package or custom token painter
- Priority: **Medium**

### 6.3 Plain Text Viewer
- Support viewing/editing plain text files (.txt, .log, .conf, .json, .yaml)
- Priority: **Medium**

### 6.4 Search Within Document
- Ctrl+F search within markdown/text content
- Highlight matches with navigation
- Priority: **Medium**

### 6.5 Table of Contents
- Auto-generate TOC sidebar from markdown headings
- Click to scroll to section
- Priority: **Low**

---

## 7. Settings & Preferences

### 7.1 Theme Customization
- Allow users to choose accent colors (beyond violet)
- Light mode option
- Custom gradient presets
- Priority: **Low**

### 7.2 Keyboard Shortcut Customization
- Configurable key bindings for all actions
- Priority: **Low**

### 7.3 Default Application Mapping
- Configure which external apps to use for specific file types
- "Open With..." context menu option
- Priority: **Medium**

### 7.4 Import/Export Settings
- Backup and restore settings to/from JSON file
- Priority: **Low**

---

## 8. Code Quality & Refactoring

### 8.1 Consolidate formatBytes (Immediate)
- Merge 4 duplicate `formatBytes`/`_formatSize` implementations into `StringUtils.formatBytes()`
- Add `double` overload for device provider use case
- **Files to update**: `directory_size_utils.dart`, `task_history_view.dart`, `playlist_overlay.dart`, `device_provider.dart`

### 8.2 Consolidate formatDuration
- Create `StringUtils.formatDuration()` with format options
- Unify video player and audio player duration formatting
- **Files to update**: `video_preview_widget.dart`, `waveform_scrubber.dart`

### 8.3 Consolidate Gradient Slider Track
- Remove `_GradientRectSliderTrackShape` from `video_volume_overlay.dart`
- Reuse existing `GradientRectSliderTrackShape` from `gradient_slider_track.dart`

### 8.4 Extract Shared Viewer Patterns
- Create `ViewerMixin` or base class for shared logic across all viewer widgets:
  - HUD auto-hide timer
  - Keyboard navigation
  - Window management boilerplate
  - IPC reverse navigation
- Reduces ~200 lines of duplicated code across 4 viewers

### 8.5 Unit Test Coverage
- Add unit tests for:
  - `DirectoryCache` TTL logic
  - `FileTypeClassifier` extension mapping
  - `StringUtils` formatting functions
  - `TabManager` state transitions
  - `ConflictProvider` queue/completer logic
- Priority: **High** — currently no test coverage

### 8.6 Widget Test Coverage
- Add widget tests for:
  - `ItemCard` selection states
  - `ContextMenu` positioning
  - `BreadcrumbSegment` navigation
  - `FilterOverlay` state management
- Priority: **Medium**

---

## Priority Summary

| Priority | Items |
|----------|-------|
| **Immediate** | formatBytes consolidation, formatDuration consolidation, gradient slider dedup |
| **High** | Isolate pool, error boundaries, list view mode, favorites, audio metadata, PDF viewer, unit tests |
| **Medium** | Dual pane, breadcrumb dropdown, undo/redo, thumbnail strip, PiP, real waveform, syntax highlighting, text viewer |
| **Low** | Plugin arch, slideshow, RAW support, equalizer, theme customization, keyboard config |

---

*Generated: 2026-05-06 | Based on comprehensive audit of OnyxCore v1.0.0 codebase.*
