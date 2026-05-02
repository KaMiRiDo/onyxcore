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
*   **Key Packages**: `flutter_svg` (vector graphics), `google_fonts` (typography), `desktop_multi_window` (multi-window IPC), `flutter_markdown` (docs viewer), native isolating tools (`dart:isolate`).
</overview>

<conventions>
## Architectural Conventions
*   **Feature-First Clean Architecture**: Strict decoupling of `domain`, `data`, and `presentation` layers within distinctly scoped feature folders (`directory_browser`, `image_viewer`, `video_player`, `settings`).
*   **Isolate-Driven I/O**: Operations that could cause frame drops or UI freezing (such as reading fat directories, `statSync` POSIX permission checks, and heavy image thumbnail decoding) are explicitly offloaded to background threads (`Isolate.run` and `Image.file(frameBuilder)`).
*   **State Decoupling**: Riverpod logic is split into highly modular files inside the `presentation/providers/` directories (e.g., separating `navigation_notifier`, `selection_notifier`, `conflict_provider`, and `directory_providers`).
*   **Theme Centralization**: Hardcoded UI coloring is prohibited outside of core presentation exceptions; the UI relies strictly on `AppColors` and customized gradients constructed via `AppTheme`.
*   **Safe Background Tasks**: Background file operations are tracked via `TaskProvider` and include safety hooks (`WidgetsBindingObserver`) to cancel operations immediately if the application is closed or detached.
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
    │   ├── domain/       # Immutable data models (FileItem, SelectionState)
    │   └── presentation/ 
    │       ├── pages/    # Master Gallery with sequential paste loops
    │       ├── providers/# Selection, Task, Clipboard, and Conflict management
    │       └── widgets/  # Grid Engine, Context Menu, Properties, and Dialogs
    ├── image_viewer/
    │   └── presentation/ # Full-bleed image previewer & FFmpeg editing overlay
    ├── settings/
    │   ├── data/         
    │   ├── domain/       
    │   └── presentation/ # Configuration providers
    └── video_player/
        └── presentation/ # Dedicated video playback routing endpoints
```
</architecture>

<current_state>
## Feature Inventory & Status

| Feature Sector | Component / Module | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Directory Browser** | UI Layout & Scaling | ✅ Full | Fluid responsive grid, zoom behaviors (default 0.9x baseline), sidebar orchestration. |
| **Directory Browser** | Iconography Engine | ✅ Full | Custom SVG file classification, directory depth styling, POSIX tracking. |
| **Directory Browser** | Selection System | ✅ Full | Additive (`Ctrl`), range (`Shift`), global deselect, and **Auto-selection on Paste/Create**. |
| **Directory Browser** | Data & Caching | ✅ Full | Isolated `statSync`, real-time `inotify` watchers, LRU caching, show hidden folders toggle. |
| **Directory Browser** | File Operations | ✅ Full | **Recursive Copy/Move/Rename** with real-time sequential conflict resolution. |
| **Directory Browser** | Conflict System | ✅ Full | Queue-based `ConflictProvider`, non-dismissible `ConflictDialog` with keyboard navigation. |
| **Directory Browser** | Error Handling | ✅ Full | `ErrorDialog` for self-overwrite and circular inclusion detection (parent-child blocking). |
| **Document Viewer** | Markdown Preview | ✅ Full | `flutter_markdown` integrated, functional standalone documentation viewer. |
| **Image Viewer** | High-Res Preview | ✅ Full | Fast sync pipelines, Next/Prev navigation support. |
| **Image Viewer** | Editor Overlay | ✅ Full | FFmpeg-based free-style crop and rotation processing (Replace & Save Copy). |
| **Multimedia** | Multi-Window Player | ✅ Full | Multi-window IPC playback, independent HUD toggling ('F'), auto-closure on finish. |
| **Settings** | Configuration UI | ✅ Full | Integrated settings overlay with markdown viewer toggles and hidden folder configurations. |
| **Cloud Services** | Sidebar Integrations | 🔲 Placeholder | Visual elements exist ("Alex's Cloud"), backend networking absent. |
</current_state>

<roadmap>
## Unresolved Gaps & Roadmap
1.  **TFLite Integration**: Solidify the background worker required to boot up the Neural Image Assessment (NIMA) model, run manual clarity scans on imagery, and hydrate the UI seamlessly.
2.  **Cloud Backend**: Implement the networking layer for sidebar cloud service providers (Google Drive/Dropbox integration).
</roadmap>
