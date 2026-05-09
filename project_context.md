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
*   **Video Player (Performance Optimized)**:
    *   **Stability**: Implemented managed stream subscriptions and `_isClosing` lifecycle guards to eliminate native playback crashes during window closure or rapid navigation.
    *   **Zero-Latency Startup**: 300ms deferred engine initialization strategy ensures the UI loader (`BubbleLoader`) animates smoothly before heavy native `libmpv` initialization.
    *   **Buffering & Cache**: High-precision `libmpv` configuration with 128MB RAM buffering (`demuxer-max-bytes`) and 60s readahead to eliminate seek stutters.
    *   **HUD & UX**: Glassmorphic HUD with movement-based triggers and standardized cinematic snapshot flash effects.
*   **Image Viewer (High Fidelity)**:
    *   **Navigation Throttle**: 500ms cooldown for rapid arrow-key navigation to prevent texture thrashing.
    *   **Cache Persistence**: 500MB dedicated image cache ensures high-resolution media remains in memory during playlist traversal.
    *   **Interaction Engine**: Unified panning/scaling logic with strict boundary clamping at 1.0x scale to prevent "zoom-drifting" UI glitches.
    *   **FFmpeg Editor**: Integrated rotational slider, brightness adjustment, and 3x3 crop grid with aspect ratio normalization.

</current_state>

<roadmap>
## Unresolved Gaps & Roadmap
1.  **[ACTIVE] BUG-001: Performance-Optimized Seek & Hover Preview**:
    *   Implementing "Sliding Window" seek logic (60s ahead / 30s behind cache).
    *   Headless `Player` instance for low-latency hover thumbnails on the progress bar.
    *   Unified Initialization UI with cross-fade transitions.
2.  **TFLite Integration**: Implement Neural Image Assessment (NIMA) for automated clarity/aesthetic scanning.
3.  **Cloud Backend**: Networking layer for Google Drive/Dropbox sidebar integrations.
4.  **Search Refinement**: Implement global file search indexing for instant results across massive directory trees.
</roadmap>

<account_transition>
## Account Transition Context (Transfer Summary)
**Current Date**: 2026-05-09
**Status**: Mid-Optimization (Performance Phase)
**Current Task**: Resolving `BUG-001` (Media Player Seek & Hover).
**Key Files for Handover**:
*   `project_context.md`: (This file) Full architectural and state overview.
*   `_prompts/BUG-001.md`: Requirements for the current active development sprint.
*   `recommended_updates.md`: Strategic roadmap for future iterations.

**Instructions for New AI Instance**: 
> "Please ingest `project_context.md` and `_prompts/BUG-001.md` to resume the media player optimization sprint. Focus on the `libmpv` sliding window cache and the headless player for hover previews as defined in BUG-001."
</account_transition>
