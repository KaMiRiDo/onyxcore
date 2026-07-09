# Downloads Panel Preview Test Plan

**File Under Test:** `lib/features/downloader/presentation/widgets/components/downloads_panel_preview.dart`
**Target Layer:** Presentation / Widgets
**Coverage Target:** >90%

## Widget Test Plan

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-DL-PRV-01 | `downloads_panel_preview.dart` | `_buildSinglePreviewOverlay` guards | render nothing when preview item, preview index, or config is missing | each dependency absent in turn | pump overlay host | returns `SizedBox.shrink()` |
| W-DL-PRV-02 | `downloads_panel_preview.dart` | single preview dismissal | close on backdrop tap and close icon, but not when dialog body is tapped | single preview visible | tap backdrop, tap close icon, tap inner panel | backdrop and icon clear `_previewItem`; inner tap is absorbed |
| W-DL-PRV-03 | `downloads_panel_preview.dart` | single preview thumbnail | render base64 thumbnails, remote thumbnails, and fallback art correctly | item with data URI, network URL, and null thumbnail | pump preview | `Image.memory`, `Image.network`, or `FallbackThumb` appears as appropriate |
| W-DL-PRV-04 | `downloads_panel_preview.dart` | single preview loading/error states | show custom loader while network image loads and fallback on image failure | network thumbnail with pending/error responses | pump frames | loading spinner then fallback widget appear |
| W-DL-PRV-05 | `downloads_panel_preview.dart` | single preview metadata | show extractor, computed size, and copy-url affordance | single item with extractor and size/URL data | pump overlay | title row, source/size row, and `CopyUrlButton` render expected values |
| W-DL-PRV-06 | `downloads_panel_preview.dart` | single preview video badge | show formatted duration for video items and `--:--` when duration is missing | single video item with and without duration | pump overlay | duration badge matches branch |
| W-DL-PRV-07 | `downloads_panel_preview.dart` | single preview format dropdown | update `config.format` when user picks a new format | item has selectable formats | change dropdown value | config format mutates and UI reflects new selection |
| W-DL-PRV-08 | `downloads_panel_preview.dart` | single preview group filter | show `GroupFilterDropdown` for multi-item previews and reset carousel index on change | multi-item group with mixed image/video content | change filter | `config.groupFilter` updates and `_previewCarouselIndex=0` |
| W-DL-PRV-09 | `downloads_panel_preview.dart` | single preview group filter enablement | disable group filter when group lacks mixed media and is not a profile | homogeneous group | pump overlay | dropdown is disabled |
| W-DL-PRV-10 | `downloads_panel_preview.dart` | single preview actions | remove current group or start its download and close preview | overlay visible | tap `Remove` and `Download` | remove path delegates to `_removeParsedItems`; download path delegates to `_startDownload` then clears preview |
| W-DL-PRV-11 | `downloads_panel_preview.dart` | `_buildGroupPreviewOverlay` guards | render nothing when group/config/index are missing or visible items are empty | incomplete preview state | pump overlay | overlay collapses safely |
| W-DL-PRV-12 | `downloads_panel_preview.dart` | group preview title normalization | rewrite profile title `item` to `@id` or URL segment fallback | profile group with generic title and populated `id` / URL path | open group preview | header title becomes human-friendly handle |
| W-DL-PRV-13 | `downloads_panel_preview.dart` | carousel index clamping | clamp out-of-range carousel indices back into the visible-item range | preview index manually set below `0` or above list length | build overlay | effective displayed item is clamped to first/last valid entry |
| W-DL-PRV-14 | `downloads_panel_preview.dart` | group preview keyboard navigation | move left/right through carousel with arrow keys and ignore out-of-range presses | multi-item visible set | send left/right keys | handled keys change `_previewCarouselIndex`; edge presses are ignored |
| W-DL-PRV-15 | `downloads_panel_preview.dart` | group preview dismissal | close on backdrop or close icon while absorbing inner taps | overlay visible | tap backdrop/icon/inner body | only allowed dismissal paths close preview |
| W-DL-PRV-16 | `downloads_panel_preview.dart` | group preview header controls | show playlist format dropdown or generic group filter depending on group type | playlist group and non-playlist group | pump overlay | playlist uses `FormatSelectionDropdown`; non-playlist uses `GroupFilterDropdown` |
| W-DL-PRV-17 | `downloads_panel_preview.dart` | group preview `Download All` | trigger grouped download and close overlay | group preview visible | tap `Download All` | `_startDownload(groupIndex)` runs and preview closes |
| W-DL-PRV-18 | `downloads_panel_preview.dart` | carousel arrows | disable previous/next buttons at ends and enable them in the middle | visible item count > 1 | inspect buttons across indices | arrow enabled states match current index |
| W-DL-PRV-19 | `downloads_panel_preview.dart` | carousel body hydration placeholder | show loader card for `hydration_loading` items | current item id is `hydration_loading` | pump overlay | custom loader fills the carousel canvas |
| W-DL-PRV-20 | `downloads_panel_preview.dart` | carousel profile fallback art | show account-circle fallback for profile items when thumbnail is missing or fails | profile group item with null/broken thumbnail | pump overlay | profile fallback art appears instead of generic thumb |
| W-DL-PRV-21 | `downloads_panel_preview.dart` | carousel video badges and counter | show duration badge for videos and `X / N` position counter for all items | visible video item and multi-item group | pump overlay | both badges render with correct values |
| W-DL-PRV-22 | `downloads_panel_preview.dart` | hydration overlay | layer live-loading veil over playlist/profile item while URL is still hydrating | background-loading URL active | pump overlay | translucent loader overlay appears above image |
| W-DL-PRV-23 | `downloads_panel_preview.dart` | footer metadata | show trimmed title plus file size and copy URL for current carousel item | current item has long title and resolvable size | pump overlay | title is middle-trimmed, size branch resolves correctly, copy button uses webpage/direct/original URL priority |
| W-DL-PRV-24 | `downloads_panel_preview.dart` | item-level format selection | store per-item format overrides in `config.itemFormats` | current item exposes formats | change item-level dropdown | selected format is saved under the current item id |
| W-DL-PRV-25 | `downloads_panel_preview.dart` | footer actions | remove just the current child item or download only that child | multi-item group visible | tap `Remove` or `Download` in footer | `_removeSingleItem` or `_startDownload(... singleItemId: currentItem.id)` is called |
| W-DL-PRV-26 | `downloads_panel_preview.dart` | `ValueListenableBuilder` refresh | rebuild group preview contents when hydration notifier ticks | notifier value changes during hydration | change notifier and pump | visible items, stats, and counter update without remounting the whole panel |

