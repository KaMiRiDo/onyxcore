# OnyxCore - Project Context Document

<overview>
## Project Overview
**Name**: OnyxCore
**Core Purpose**: A high-performance, pixel-perfect Linux desktop file manager and multimedia explorer. It is designed to prioritize immersive archival aesthetics, fluid media consumption, and responsive system interactions without compromising on performance overhead.
**Aesthetic**: "Natural Archive" - Features a sleek, vibrant dark mode architecture, subtle glassmorphism, depth-based shading, custom SVG iconography prioritizations, and dynamic, micro-animated interactions.
**Tech Stack**:
*   **Target**: Linux Desktop natively
*   **Framework**: Flutter & Dart
*   **State Management**: Riverpod (Providers, AsyncNotifiers)
*   **Key Packages**: `flutter_svg` (vector graphics), `google_fonts` (typography), `desktop_multi_window` (multi-window IPC), `flutter_markdown` (docs viewer), native isolating tools (`dart:isolate`), `uuid` (task tracking), `shared_preferences` (settings & history).
</overview>

<conventions>
## Architectural Conventions
*   **Feature-First Clean Architecture**: Strict decoupling of `domain`, `data`, and `presentation` layers within distinctly scoped feature folders (`directory_browser`, `image_viewer`, `video_player`, `settings`).
*   **Isolate-Driven I/O**: Operations that could cause frame drops or UI freezing (such as reading fat directories, `statSync` POSIX permission checks, and heavy image thumbnail decoding) are explicitly offloaded to background threads (`Isolate.run` and `Image.file(frameBuilder)`).
*   **Concurrent Task Management**: File operations (Copy/Move) are managed by a centralized `TaskProvider` supporting configurable concurrency limits (default 3), a "Pending" queue, and real-time ETA calculation.
*   **Task History Persistence**: Completed and failed tasks are automatically serialized to `~/.config/onyxcore/task_history.json` for persistent audit logs, categorized by date.
*   **Theme Centralization**: Hardcoded UI coloring is prohibited outside of core presentation exceptions; the UI relies strictly on `AppColors` and customized gradients constructed via `AppTheme`.
</conventions>

<architecture>
## Architecture Tree
```text
lib/
├── app.dart
├── main.dart
├── core/
│   ├── cache/            # LRU caching for instantaneous directory reloading
│   ├── errors/           # Unified Domain exceptions and failures
│   ├── platform/         # Native Linux hooks (Directory watcher via inotify)
│   ├── theme/            # Design system tokens and styling rules
│   ├── utils/            # Extension methods, FileType classifiers, and DirectorySizeUtils
│   └── window_management/# Persistent viewer managers and multi-window IPC
└── features/
    ├── directory_browser/
    │   ├── data/         # Background isolates for I/O, storage repositories
    │   ├── domain/       # Immutable data models (FileItem, SelectionState, FileTask)
    │   └── presentation/ 
    │       ├── pages/    # Master Gallery with integrated Side Panel layout
    │       ├── providers/# Selection, Task, History, Clipboard, and Conflict management
    │       └── widgets/  
    │           ├── background_panel.dart # Expandable side panel for task management
    │           ├── background_processes_button.dart # Pie-chart progress indicator
    │           ├── file_grid.dart        # Main grid engine with drag-and-drop
    │           ├── sidebar/              # Nav sidebar with filtered device detection
    │           └── task_tile.dart        # Real-time task status with log buffering
    ├── image_viewer/
    ├── settings/
    │   └── presentation/ # Configuration UI (Concurrency, Hidden files, etc.)
    └── video_player/
```
</architecture>

<current_state>
## Feature Inventory & Status

### Directory Browser
*   **UI Layout & Scaling**: Responsive grid architecture with an **inline Side Panel** (25% width) to seamlessly display background processes.
*   **Selection System**: Decoupled rubber-band rendering that avoids UI thread drops. Integrates hardware keyboard modifiers (`Shift` for range, `Ctrl` for additive) alongside standard multi-selection state management.
*   **TopBar Navigation**: GNOME-inspired breadcrumb navigation. Supports hovering over breadcrumbs for 1000ms to instantly navigate, or dropping files directly onto breadcrumbs to execute a targeted move.
*   **Inline Location Editing**: Clicking the breadcrumb instantly transitions it into a text input for manual path entry. Invalid paths show a 2-second error feedback.
*   **Search Context**: Integrated "Instant Search" dynamically switches the breadcrumbs to a search bar. Features a rich "No Results Found" graphic when a search query is unmatched. Auto-collapses upon directory navigation.
*   **File Operations (Copy/Move/Paste/Drag-and-Drop)**: Robust concurrent system with self-overwrite and circular-reference protections (e.g., preventing copying a folder into its own subdirectory). Context menu integrated with Paste, New Folder, and Properties.
*   **Rename Capabilities**: `F2` shortcut triggers a positioned rename popover for single items or a bulk-rename dialog for multiple selections (Prefix and Base Name modes).
*   **Delete Protections**: "Trash" fallback functionality. Shift+Delete prompts a prominent permanent deletion warning.

### Task & Conflict Management
*   **Concurrent Task Management**: Global `TaskProvider` handling a user-configurable concurrency limit (1-10) for disk operations, displaying real-time ETA and success/error logs.
*   **History Logs**: Completed and failed tasks serialize to `task_history.json`, maintaining an audit log sectioned by date, accessible via drill-down UI.
*   **Conflict Handling**: Queue-based `ConflictProvider` that pauses operations to prompt the user to Overwrite, Skip, or Auto-Rename. Renaming automatically appends counter indices `(1)`, `(2)` to file basenames.
*   **Progress Indicators**: Pie-chart style button in the top bar to display overall progress at a glance, turning red if a task fails.

### Sidebar & Settings
*   **Filtered Navigation**: Dynamic detection of devices, filtering out redundant system mounts (like removing "File System" when inside "Home").
*   **Configuration**: Settings dialog allows toggling visibility of hidden files and tweaking background concurrency limits.
*   **Persistent Layout**: Changes save to local preferences and load instantly.

### Media Viewers (Images & Video)
*   **Multi-Window Architecture**: Utilizes `desktop_multi_window` for true independent viewer windows.
*   **IPC Media Navigation**: Viewers communicate directly with the main engine (`WindowController` 0) via JSON payloads to request next/previous files without re-indexing directories.
*   **Video Player**: Media Kit integration with fast-seeking (`Left`/`Right` arrows skip 10s), 0-200% volume amplification (`Up`/`Down` arrows), and a standardized HUD overlay.
*   **Image Editor**: FFmpeg-powered editing overlay featuring:
    *   0 to 360° rotational slider with a custom painter.
    *   Interactive -1.0 to 1.0 brightness slider.
    *   Draggable 3x3 crop grid handling aspect ratio normalization.
    *   Export modes: "Replace" (overwrites original file) and "Save Copy" (appends `copy_` to basename, auto-incrementing if conflicts exist).

</current_state>

<roadmap>
## Unresolved Gaps & Roadmap
1.  **TFLite Integration**: Implement Neural Image Assessment (NIMA) for automated clarity/aesthetic scanning.
2.  **Cloud Backend**: Networking layer for Google Drive/Dropbox sidebar integrations.
3.  **Search Refinement**: Implement global file search indexing for instant results across massive directory trees.
</roadmap>
