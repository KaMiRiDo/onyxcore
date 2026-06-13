# MarkdownPreviewWidget Test Design Document

**Target File:** `lib/features/document_viewer/presentation/widgets/markdown_preview_widget.dart`
**Layer:** Presentation / Widgets

This document covers the widget tests for the MarkdownPreviewWidget, which is responsible for rendering the live preview, YAML frontmatter, Kroki math APIs, and Mermaid diagrams using `flutter_html`.

## 1. Widget Test Plan Format

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DOC-PREVIEW-01 | `markdown_preview_widget.dart` | `MarkdownPreviewWidget` | Render standard Markdown content | Given a widget pumped with `## Hello` and `**bold**` | User views the widget | `Html` widget renders the corresponding parsed tags and text. |
| W-DOC-PREVIEW-02 | `markdown_preview_widget.dart` | `MarkdownPreviewWidget` | Render YAML Frontmatter and tag badges | Given markdown starting with `---` containing `title: Foo` and `tags: [a, b]` | User views the widget | The frontmatter table is rendered with `Foo` and badge `Container`s for tags. |
| W-DOC-PREVIEW-03 | `markdown_preview_widget.dart` | `_buildMathJax` | Pre-process and render Math equations via Kroki | Given `$$ E=mc^2 $$` in the content | User views the widget | The widget tree contains `SvgPicture` pointing to `kroki.io` with the encoded payload. |
| W-DOC-PREVIEW-04 | `markdown_preview_widget.dart` | `_buildMermaidDiagram` | Render Mermaid diagram using `flutter_mermaid` | Given ` ```mermaid \n graph TD \n A-->B \n ``` ` | User views the widget | The widget tree contains a `MermaidDiagram` widget with the parsed code containing `theme: dark`. |
| W-DOC-PREVIEW-05 | `markdown_preview_widget.dart` | `_buildCodeBlock` | Render custom code blocks with language and copy button | Given a code block ` ```dart \n print() \n ``` ` | User taps the copy button | `Clipboard.setData` is called with the code block content. |
| W-DOC-PREVIEW-06 | `markdown_preview_widget.dart` | `ScrollConfiguration` | Sync scroll with editor in dual pane mode | Given `isDualPane = false` and user taps/scrolls the markdown preview | User touches the preview | Editor scroll controller updates via `jumpTo` proportionally to the tapped position. |
| W-DOC-PREVIEW-07 | `markdown_preview_widget.dart` | `TextField` | Update live preview while editing | Given `isDualPane = false` | User types in the editor text field | The `Html` widget rebuilds with the updated markdown content. |
| W-DOC-PREVIEW-08 | `markdown_preview_widget.dart` | `MarkdownPreviewWidget` | Ctrl+W closes the preview window from document preview mode | Given `MarkdownPreviewWidget` is pushed as standalone | User presses Ctrl+W | Widget pops and disappears from widget tree. |
| W-DOC-PREVIEW-09 | `markdown_preview_widget.dart` | `TagExtension` | Render task list checkboxes | Given markdown `- [x] Task` | User views the widget | `Html` widget renders `Icons.check_box_rounded` or `Icons.check_box_outline_blank_rounded`. |
| W-DOC-PREVIEW-10 | `markdown_preview_widget.dart` | `Style` | Render tables with borders and styled headers | Given markdown table | User views the widget | `Html` renders the table utilizing proper `Style` configurations for `th` and `td`. |
| W-DOC-PREVIEW-11 | `markdown_preview_widget.dart` | `Dual Pane Divider` | Resize dual pane using divider | Given `isDualPane = true` | User drags the divider left or right | `_editorWidthRatio` changes, resizing the UI accordingly. |
| W-DOC-PREVIEW-12 | `markdown_preview_widget.dart` | `ScrollController` | Synchronize dual pane scrolling | Given `isDualPane = true` and `_editorScrollController` moves | Editor triggers scroll listener | `_lineNumbersScrollController` and preview controllers jump to matching offsets. |
| W-DOC-PREVIEW-13 | `markdown_preview_widget.dart` | `MermaidOfflineRenderer` | Handle complex mermaid diagrams with newlines | Given multiline complex mermaid syntax | The widget renders the diagram | Diagram renders successfully via `flutter_html` and `MermaidOfflineRenderer.renderToPng`. |
| W-DOC-PREVIEW-14 | `markdown_preview_widget.dart` | `ListView` | Line numbers padding syncs with editor padding | Given editor rendering in dual pane | Verify line number container | `ListView` has `padding: EdgeInsets.only(top: 24, bottom: 24)` explicitly inside the scrollable to align with `TextField`. |
| W-DOC-PREVIEW-16 | `markdown_preview_widget.dart` | `MarkdownPreviewWidget` | Clicking preview opens editor with cursor at correct line | Given `isDualPane = true` | User clicks on a specific paragraph in the preview | `onTapUp` sets cursor selection offset proportionally to the clicked Y coordinate. |
