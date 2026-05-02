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

| Feature Sector | Component / Module | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Directory Browser** | UI Layout & Scaling | ✅ Full | Responsive grid with **inline Side Panel** for background processes. |
| **Directory Browser** | Selection System | ✅ Full | Additive (`Ctrl`), range (`Shift`), and rubber-band selection. |
| **Directory Browser** | File Operations | ✅ Full | **Concurrent Copy/Move** with real-time logs and individual cancellation. |
| **Task Management** | Background Panel | ✅ Full | Side panel (25% width) with active tasks and history sub-views. |
| **Task Management** | Progress Button | ✅ Full | Pie-chart style TopBar button with success/error state transitions. |
| **Task Management** | History Logs | ✅ Full | Persistent JSON storage with date-based sectioning and log detail drill-down. |
| **Conflict System** | Conflict Handling | ✅ Full | Queue-based `ConflictProvider` with overwrite/skip/auto-rename logic. |
| **Sidebar** | Navigation | ✅ Full | Filtered list; removed redundant 'File System'/'Home' from Devices section. |
| **Image Viewer** | Editor Overlay | ✅ Full | FFmpeg-based crop/rotation with "Replace" and "Save Copy" support. |
| **Settings** | Configuration | ✅ Full | Configurable **Max Concurrent Tasks** (1-10) and hidden file toggles. |
</current_state>

<roadmap>
## Unresolved Gaps & Roadmap
1.  **TFLite Integration**: Implement Neural Image Assessment (NIMA) for automated clarity/aesthetic scanning.
2.  **Cloud Backend**: Networking layer for Google Drive/Dropbox sidebar integrations.
3.  **Search Refinement**: Implement global file search indexing for instant results across massive directory trees.
</roadmap>
