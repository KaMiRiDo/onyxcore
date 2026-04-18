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
*   **Key Packages**: `flutter_svg` (vector graphics), `google_fonts` (typography), native isolating tools (`dart:isolate`).
</overview>

<conventions>
## Architectural Conventions
*   **Feature-First Clean Architecture**: Strict decoupling of `domain`, `data`, and `presentation` layers within distinctly scoped feature folders (`directory_browser`, `image_viewer`, `video_player`, `settings`).
*   **Isolate-Driven I/O**: Operations that could cause frame drops or UI freezing (such as reading fat directories, `statSync` POSIX permission checks, and heavy image thumbnail decoding) are explicitly offloaded to background threads (`Isolate.run` and `Image.file(frameBuilder)`).
*   **State Decoupling**: Riverpod logic is split into highly modular files inside the `presentation/providers/` directories (e.g., separating `navigation_notifier`, `selection_notifier`, and `directory_providers`).
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
│   └── utils/            # Extension methods and FileType classifiers/configs
└── features/
    ├── directory_browser/
    │   ├── data/         # Background isolates for I/O, storage repositories
    │   ├── domain/       # Immutable data models (FileItem, SelectionState)
    │   └── presentation/ # Master Gallery, Grid Engine, Sidebar, selection logic
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
| **Directory Browser** | UI Layout & Scaling | ✅ Full | Fluid responsive grid, zoom behaviors (default 0.8x), sidebar orchestration. |
| **Directory Browser** | Iconography Engine | ✅ Full | Complete SVG mappings, directory depth shading, POSIX executable tracking. |
| **Directory Browser** | Selection System | ✅ Full | Additive multi-select (`Ctrl`), range select (`Shift`), and global deselect. |
| **Directory Browser** | Data & Caching | ✅ Full | Isolated `statSync`, real-time `inotify` watchers, LRU directory caching. |
| **Directory Browser** | File Operations | ⚠️ Partial| Trash/Delete confirmed. Copy/Move/Rename placeholders exist. |
| **Image Viewer** | High-Res Preview | ✅ Full | Synchronous rendering pipelines with placeholder fallbacks. |
| **Image Viewer** | Editor Overlay | ⚠️ Partial| Free-style crop and rotation UI implemented; FFmpeg execution backend pending. |
| **Image Analysis** | AI Clarity Scoring | ⚠️ Partial| UI hooks created; NIMA TFLite model integration needed. |
| **Multimedia** | Video Player | 🔲 Placeholder | UI routed, but `video_player` lacks stable Linux dependencies. |
| **Cloud Services** | Sidebar Integrations | 🔲 Placeholder | Visual elements exist ("Alex's Cloud"), backend networking completely absent. |
</current_state>

<roadmap>
## Unresolved Gaps & Roadmap
1.  **Video Player Implementation**: Integrate a stable Linux native multimedia player component (such as `ffmpeg_kit_flutter` or a Dart FFI wrapper for `mpv`) to resolve the existing `MissingPluginException` for video playback features.
2.  **Physical File Operations**: Build the concrete I/O execution logic in `DirectoryRepositoryImpl` spanning Copy, Move, and Rename commands.
3.  **TFLite Integration**: Solidify the background worker required to boot up the Neural Image Assessment (NIMA) model, run manual clarity scans on imagery, and hydrate the UI seamlessly.
4.  **FFmpeg Image Writes**: Wire the visual crop/rotation offsets registered inside the `image_editor_overlay` to the native FFmpeg binary to actually slice and persist the image modifications to disk.
</roadmap>
