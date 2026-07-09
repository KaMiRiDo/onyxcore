## Unit Test Plan

> N/A - `ViewerTopBar` is a pure presentation widget. All meaningful logic (conditional rendering, callbacks, layout, and the `_trimMiddle()` helper) can be fully exercised through widget tests.

---

## Widget Test Plan

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---------|--------------------|-----------------------|-------------------------|-----------------------|---------------|-------------------|
| W-VTB-001 | viewer_top_bar.dart | ViewerTopBar | Render successfully with minimum required parameters | title only | pumpWidget() | Widget renders without exception |
| W-VTB-002 | viewer_top_bar.dart | ViewerTopBar | Render Material widget | Default widget | Pump | Finds Material |
| W-VTB-003 | viewer_top_bar.dart | ViewerTopBar | Render transparent Material | Default widget | Pump | Material.type == transparency |
| W-VTB-004 | viewer_top_bar.dart | ViewerTopBar | Apply container padding of 24 | Default widget | Pump | Padding == EdgeInsets.all(24) |
| W-VTB-005 | viewer_top_bar.dart | ViewerTopBar | Apply top-to-bottom gradient | Default widget | Pump | LinearGradient configured correctly |
| W-VTB-006 | viewer_top_bar.dart | ViewerTopBar | Render Row layout | Default widget | Pump | Finds one Row |
| W-VTB-007 | viewer_top_bar.dart | ViewerTopBar | Render Expanded title section | Default widget | Pump | Expanded widget exists |
| W-VTB-008 | viewer_top_bar.dart | ViewerTopBar | Render title Text | title="Image.png" | Pump | Text displayed |

---

### Title Rendering

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-009 | viewer_top_bar.dart | Title | Display complete title when shorter than trim limit | Short title | Pump | Full title displayed |
| W-VTB-010 | viewer_top_bar.dart | Title | Trim long title in the middle | Title >50 chars | Pump | Text contains "..." |
| W-VTB-011 | viewer_top_bar.dart | Title | Preserve beginning after trimming | Long title | Pump | Prefix retained |
| W-VTB-012 | viewer_top_bar.dart | Title | Preserve ending after trimming | Long title | Pump | Suffix retained |
| W-VTB-013 | viewer_top_bar.dart | Title | Do not trim title exactly 50 characters | Length=50 | Pump | Full title displayed |
| W-VTB-014 | viewer_top_bar.dart | Title | Do not trim title shorter than max length | Length=49 | Pump | Full title displayed |
| W-VTB-015 | viewer_top_bar.dart | Title | Trim unicode filename correctly | Malayalam/Japanese filename >50 chars | Pump | Trimmed correctly |
| W-VTB-016 | viewer_top_bar.dart | Title | Trim emoji-containing filename correctly | Emoji filename | Pump | No broken characters |
| W-VTB-017 | viewer_top_bar.dart | Title | Preserve grapheme clusters during trimming | Combined unicode characters | Pump | No malformed text |

---

### Tooltip

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-018 | viewer_top_bar.dart | Tooltip | Display tooltip with original title | Long title | Hover | Tooltip visible |
| W-VTB-019 | viewer_top_bar.dart | Tooltip | Tooltip shows untrimmed title | Long title | Hover | Full title displayed |
| W-VTB-020 | viewer_top_bar.dart | Tooltip | Tooltip waitDuration is 500ms | Default widget | Inspect | waitDuration == 500ms |

---

### Metadata

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-021 | viewer_top_bar.dart | Metadata | Hide metadata when null | metadata=null | Pump | Metadata Text absent |
| W-VTB-022 | viewer_top_bar.dart | Metadata | Display metadata when supplied | metadata="1920×1080" | Pump | Metadata visible |
| W-VTB-023 | viewer_top_bar.dart | Metadata | Insert SizedBox(height:4) above metadata | Metadata supplied | Pump | SizedBox(height:4) exists |
| W-VTB-024 | viewer_top_bar.dart | Metadata | Display unicode metadata | Malayalam metadata | Pump | Metadata rendered |
| W-VTB-025 | viewer_top_bar.dart | Metadata | Handle empty metadata string | metadata="" | Pump | Empty Text rendered without exception |

---

### Leading Actions

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-026 | viewer_top_bar.dart | Leading Actions | Hide leading actions when null | leadingActions=null | Pump | No leading widgets |
| W-VTB-027 | viewer_top_bar.dart | Leading Actions | Render single leading action | One IconButton | Pump | Action visible |
| W-VTB-028 | viewer_top_bar.dart | Leading Actions | Render multiple leading actions | Two widgets | Pump | Both widgets visible |
| W-VTB-029 | viewer_top_bar.dart | Leading Actions | Insert spacing after leading actions | Leading widgets present | Pump | SizedBox(width:16) exists |

---

### Extra Actions

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-030 | viewer_top_bar.dart | Extra Actions | Hide extra actions when null | extraActions=null | Pump | No extra widgets |
| W-VTB-031 | viewer_top_bar.dart | Extra Actions | Render single extra action | One widget | Pump | Widget visible |
| W-VTB-032 | viewer_top_bar.dart | Extra Actions | Render multiple extra actions | Three widgets | Pump | All widgets visible |

---

### Pop Out Button

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-033 | viewer_top_bar.dart | PopOut Button | Display Pop Out button | onPopOut provided | Pump | Button visible |
| W-VTB-034 | viewer_top_bar.dart | PopOut Button | Hide Pop Out button when callback null | onPopOut=null | Pump | Button absent |
| W-VTB-035 | viewer_top_bar.dart | PopOut Button | Invoke callback when tapped | Mock callback | Tap | Callback invoked once |
| W-VTB-036 | viewer_top_bar.dart | PopOut Button | Tooltip displays "Pop Out" | Hover | Pump | Tooltip visible |
| W-VTB-037 | viewer_top_bar.dart | PopOut Button | Display correct icon | Pump | Inspect | open_in_new_rounded shown |

---

### Close Button

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-038 | viewer_top_bar.dart | Close Button | Display Close button | onClose provided | Pump | Close button visible |
| W-VTB-039 | viewer_top_bar.dart | Close Button | Hide Close button when callback null | onClose=null | Pump | Close button absent |
| W-VTB-040 | viewer_top_bar.dart | Close Button | Invoke callback when tapped | Mock callback | Tap | Callback invoked once |
| W-VTB-041 | viewer_top_bar.dart | Close Button | Tooltip displays "Close" | Hover | Pump | Tooltip visible |
| W-VTB-042 | viewer_top_bar.dart | Close Button | Display close icon | Pump | Inspect | close_rounded shown |

---

### Standalone Mode

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-043 | viewer_top_bar.dart | Standalone Mode | Hide Pop Out button in standalone mode | isStandalone=true | Pump | Pop Out absent |
| W-VTB-044 | viewer_top_bar.dart | Standalone Mode | Hide Close button in standalone mode | isStandalone=true | Pump | Close absent |
| W-VTB-045 | viewer_top_bar.dart | Standalone Mode | Hide action spacing | Standalone=true | Pump | Action spacing absent |
| W-VTB-046 | viewer_top_bar.dart | Standalone Mode | Still render extra actions | Extra actions supplied | Pump | Extra actions visible |

---

### _buildButton()

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-047 | viewer_top_bar.dart | _buildButton | Render IconButton inside decorated Container | PopOut button | Pump | Container exists |
| W-VTB-048 | viewer_top_bar.dart | _buildButton | Apply borderRadius=12 | Pump | Inspect | Radius ==12 |
| W-VTB-049 | viewer_top_bar.dart | _buildButton | Apply semi-transparent background | Pump | Inspect | Background opacity correct |
| W-VTB-050 | viewer_top_bar.dart | _buildButton | Apply splashRadius=24 | Pump | Inspect | splashRadius==24 |
| W-VTB-051 | viewer_top_bar.dart | _buildButton | Render white icon | Pump | Inspect | Icon color==white |
| W-VTB-052 | viewer_top_bar.dart | _buildButton | Render icon size 20 | Pump | Inspect | Icon size==20 |

---

### Layout

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-053 | viewer_top_bar.dart | Layout | Spacer width 48 always rendered | Default widget | Pump | SizedBox(width:48) exists |
| W-VTB-054 | viewer_top_bar.dart | Layout | Render inside Stack | Pump in Stack | Pump | No exception |
| W-VTB-055 | viewer_top_bar.dart | Layout | Render inside Positioned | Pump | Pump | No exception |
| W-VTB-056 | viewer_top_bar.dart | Layout | Render inside Overlay | Pump | Pump | Widget stable |

---

### Boundary Conditions

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-057 | viewer_top_bar.dart | Boundary | Empty title | title="" | Pump | No exception |
| W-VTB-058 | viewer_top_bar.dart | Boundary | Extremely long filename | 5000 chars | Pump | Trimmed correctly |
| W-VTB-059 | viewer_top_bar.dart | Boundary | Unicode filename | Malayalam/Japanese | Pump | Renders correctly |
| W-VTB-060 | viewer_top_bar.dart | Boundary | Emoji filename | Emoji string | Pump | Grapheme-safe rendering |
| W-VTB-061 | viewer_top_bar.dart | Boundary | Empty metadata | metadata="" | Pump | No exception |
| W-VTB-062 | viewer_top_bar.dart | Boundary | Many extra actions | 10 widgets | Pump | All rendered |
| W-VTB-063 | viewer_top_bar.dart | Boundary | Many leading actions | 10 widgets | Pump | All rendered |
| W-VTB-064 | viewer_top_bar.dart | Boundary | Parent rebuild | StatefulBuilder | setState() | Widget stable |
| W-VTB-065 | viewer_top_bar.dart | Boundary | Rapid button taps | Mock callback | Tap repeatedly | Callback count matches taps |

---

### Golden Tests

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-VTB-066 | viewer_top_bar.dart | Golden | Default viewer top bar | Pump | Capture | Matches golden |
| W-VTB-067 | viewer_top_bar.dart | Golden | Metadata displayed | Metadata | Capture | Matches golden |
| W-VTB-068 | viewer_top_bar.dart | Golden | Standalone mode | isStandalone=true | Capture | Matches golden |
| W-VTB-069 | viewer_top_bar.dart | Golden | Long filename trimmed | Long title | Capture | Matches golden |
| W-VTB-070 | viewer_top_bar.dart | Golden | With leading & extra actions | Multiple actions | Capture | Matches golden |

---

## Coverage Notes

### Expected Coverage

This file should realistically achieve **100% widget coverage**.

### Critical Branches Covered

- ✅ `metadata == null / != null`
- ✅ `leadingActions == null / != null`
- ✅ `extraActions == null / != null`
- ✅ `isStandalone == true / false`
- ✅ `onPopOut == null / != null`
- ✅ `onClose == null / != null`
- ✅ `_trimMiddle()` early return (short title)
- ✅ `_trimMiddle()` trimming branch
- ✅ Unicode/grapheme-safe trimming (`characters.take()` / `takeLast()`)
- ✅ `_buildButton()` rendering
- ✅ Button callbacks
- ✅ Tooltip rendering
- ✅ Boundary conditions
- ✅ Golden rendering

### High-Priority Coverage Tests

To maximize coverage quickly, prioritize:

1. **W-VTB-010** – Long title trimming (`_trimMiddle()` branch)
2. **W-VTB-013** – Exact boundary (50 characters)
3. **W-VTB-021 / W-VTB-022** – Metadata branches
4. **W-VTB-026 / W-VTB-028** – Leading actions branches
5. **W-VTB-030 / W-VTB-032** – Extra actions branches
6. **W-VTB-033 / W-VTB-034** – Pop Out button branches
7. **W-VTB-038 / W-VTB-039** – Close button branches
8. **W-VTB-043** – Standalone mode branch
9. **W-VTB-047 → W-VTB-052** – `_buildButton()` rendering
10. **W-VTB-057 → W-VTB-060** – `_trimMiddle()` Unicode and boundary cases

These tests exercise every conditional path in `ViewerTopBar`, including the private `_trimMiddle()` helper and `_buildButton()` method, making this another excellent candidate for **100% coverage**. :contentReference[oaicite:0]{index=0}