## Unit Test Plan

> N/A - `SearchReplaceOverlay` is a stateful presentation widget. All meaningful logic is tightly coupled with Flutter widgets, state management, keyboard shortcuts, and callbacks. Complete coverage should be achieved through widget tests.

---

## Widget Test Plan

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---------|--------------------|-----------------------|-------------------------|-----------------------|---------------|-------------------|
| W-SRO-001 | search_replace_overlay.dart | SearchReplaceOverlay | Render successfully with default parameters | Valid callbacks and default values | pumpWidget() | Overlay renders without exception |
| W-SRO-002 | search_replace_overlay.dart | SearchReplaceOverlay | Auto-focus search field after first frame | Pump widget | pumpAndSettle() | Search TextField has focus |
| W-SRO-003 | search_replace_overlay.dart | initState() | Initialize search controller with initialQuery | initialQuery="flutter" | Pump widget | Search field contains "flutter" |
| W-SRO-004 | search_replace_overlay.dart | initState() | Initialize replace controller empty | Pump widget | Inspect Replace controller | Replace field initially empty |
| W-SRO-005 | search_replace_overlay.dart | didUpdateWidget() | Update search field when initialQuery changes | Parent rebuild with new query | pumpWidget() | Search text updated |
| W-SRO-006 | search_replace_overlay.dart | didUpdateWidget() | Do not overwrite user edits when query unchanged | User modifies search | Parent rebuild same query | User text preserved |
| W-SRO-007 | search_replace_overlay.dart | dispose() | Dispose controllers without exception | Remove widget | pumpWidget() | No FlutterError |
| W-SRO-008 | search_replace_overlay.dart | dispose() | Dispose FocusNode correctly | Remove widget | pumpWidget() | No focus leak |

### Search Field

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks | Action | Assertions |
|---------|--------------------|-----------------------|-------------------------|---------------|--------|------------|
| W-SRO-009 | search_replace_overlay.dart | Search TextField | Invoke onSearchChanged when typing | Mock callback | Enter text | Callback invoked with entered text |
| W-SRO-010 | search_replace_overlay.dart | Search TextField | Show initial search query | initialQuery="abc" | Pump | Text visible |
| W-SRO-011 | search_replace_overlay.dart | Search TextField | Accept empty string | Clear field | Enter empty | Callback receives empty string |
| W-SRO-012 | search_replace_overlay.dart | Search TextField | Accept multiline paste | Paste multiline text | Enter text | Callback invoked correctly |
| W-SRO-013 | search_replace_overlay.dart | Search TextField | Accept unicode characters | Malayalam/Japanese text | Enter text | Callback receives unicode |
| W-SRO-014 | search_replace_overlay.dart | Search TextField | Accept regex characters | ".*[a-z]+" | Enter | Callback invoked |
| W-SRO-015 | search_replace_overlay.dart | Search TextField | Accept very long search string | 500-character string | Enter | No overflow or exception |

### Match Counter

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-SRO-016 | search_replace_overlay.dart | Match Counter | Hide counter when search empty | Empty query | Pump | Counter absent |
| W-SRO-017 | search_replace_overlay.dart | Match Counter | Display "1 of N" correctly | total=5,current=0 | Pump | "1 of 5" visible |
| W-SRO-018 | search_replace_overlay.dart | Match Counter | Display current index correctly | total=10,current=4 | Pump | "5 of 10" |
| W-SRO-019 | search_replace_overlay.dart | Match Counter | Display "0 of 0" when no matches | query exists,total=0 | Pump | "0 of 0" |
| W-SRO-020 | search_replace_overlay.dart | Match Counter | Update after widget rebuild | Change match count | Rebuild | Updated counter shown |

### Navigation Buttons

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-SRO-021 | search_replace_overlay.dart | Previous Button | Disable Previous on first match | current=0 | Pump | Button disabled |
| W-SRO-022 | search_replace_overlay.dart | Previous Button | Enable Previous when possible | current=2 | Pump | Button enabled |
| W-SRO-023 | search_replace_overlay.dart | Previous Button | Invoke onPrev | Enabled | Tap | Callback invoked |
| W-SRO-024 | search_replace_overlay.dart | Next Button | Disable Next on last match | current=last | Pump | Disabled |
| W-SRO-025 | search_replace_overlay.dart | Next Button | Enable Next when possible | current=1,total=5 | Pump | Enabled |
| W-SRO-026 | search_replace_overlay.dart | Next Button | Invoke onNext | Enabled | Tap | Callback invoked |
| W-SRO-027 | search_replace_overlay.dart | Keyboard Shortcut | Enter triggers next | Next enabled | Press Enter | onNext invoked |
| W-SRO-028 | search_replace_overlay.dart | Keyboard Shortcut | Shift+Enter triggers previous | Previous enabled | Shift+Enter | onPrev invoked |
| W-SRO-029 | search_replace_overlay.dart | Keyboard Shortcut | Escape closes overlay | Overlay shown | Esc | onClose invoked |
| W-SRO-030 | search_replace_overlay.dart | Keyboard Shortcut | Enter ignored when Next disabled | Last match | Enter | Callback not invoked |
| W-SRO-031 | search_replace_overlay.dart | Keyboard Shortcut | Shift+Enter ignored when Previous disabled | First match | Shift+Enter | Callback not invoked |

### Replace Section

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-SRO-032 | search_replace_overlay.dart | Replace Toggle | Expand replace section | Preview=false | Tap FindReplace icon | Replace UI visible |
| W-SRO-033 | search_replace_overlay.dart | Replace Toggle | Collapse replace section | Expanded | Tap again | Replace UI hidden |
| W-SRO-034 | search_replace_overlay.dart | Replace Toggle | Hide toggle in preview mode | Preview=true | Pump | Toggle absent |
| W-SRO-035 | search_replace_overlay.dart | Replace TextField | Accept replacement text | Type text | Enter | Text visible |
| W-SRO-036 | search_replace_overlay.dart | Replace Button | Invoke onReplace | Matches exist | Tap Replace | Callback invoked |
| W-SRO-037 | search_replace_overlay.dart | Replace Button | Disabled when no matches | total=0 | Pump | Button disabled |
| W-SRO-038 | search_replace_overlay.dart | Replace Button | Ignore tap when disabled | total=0 | Tap | Callback not invoked |
| W-SRO-039 | search_replace_overlay.dart | Replace All Button | Invoke ReplaceAll callback | Matches exist | Tap Replace All | Callback invoked |
| W-SRO-040 | search_replace_overlay.dart | Replace All Button | Disabled without matches | total=0 | Pump | Disabled |
| W-SRO-041 | search_replace_overlay.dart | Replace Field Shortcut | Enter triggers Replace | Matches exist | Press Enter | onReplace invoked |
| W-SRO-042 | search_replace_overlay.dart | Replace Field Shortcut | Escape closes overlay | Replace focused | Esc | onClose invoked |

### Toggle Buttons

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-SRO-043 | search_replace_overlay.dart | Case Toggle | Toggle case sensitivity ON | Initial=false | Tap Aa | Callback(true) |
| W-SRO-044 | search_replace_overlay.dart | Case Toggle | Toggle case sensitivity OFF | Initial=true | Tap Aa | Callback(false) |
| W-SRO-045 | search_replace_overlay.dart | Regex Toggle | Toggle regex ON | Initial=false | Tap .* | Callback(true) |
| W-SRO-046 | search_replace_overlay.dart | Regex Toggle | Toggle regex OFF | Initial=true | Tap .* | Callback(false) |
| W-SRO-047 | search_replace_overlay.dart | Toggle Styling | Highlight active case toggle | Active=true | Pump | Active color shown |
| W-SRO-048 | search_replace_overlay.dart | Toggle Styling | Highlight active regex toggle | Active=true | Pump | Active color shown |

### No Results

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-SRO-049 | search_replace_overlay.dart | No Results Banner | Show "No results" | Query exists,total=0 | Pump | Banner visible |
| W-SRO-050 | search_replace_overlay.dart | No Results Banner | Hide banner when matches exist | total>0 | Pump | Banner absent |
| W-SRO-051 | search_replace_overlay.dart | No Results Banner | Hide banner for empty query | Empty search | Pump | Banner absent |

### Drag Support

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-SRO-052 | search_replace_overlay.dart | Drag Handle | Show drag icon when callback provided | onDragUpdate!=null | Pump | Drag icon visible |
| W-SRO-053 | search_replace_overlay.dart | Drag Handle | Hide drag icon when callback null | onDragUpdate=null | Pump | Drag icon absent |
| W-SRO-054 | search_replace_overlay.dart | Drag Handle | Invoke drag callback | Mock callback | Drag | Callback invoked |

### Icon Buttons

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-SRO-055 | search_replace_overlay.dart | Close Button | Close overlay | Tap close | Callback | onClose invoked |
| W-SRO-056 | search_replace_overlay.dart | Tooltip | Verify Previous tooltip | Hover | Pump | Tooltip shown |
| W-SRO-057 | search_replace_overlay.dart | Tooltip | Verify Next tooltip | Hover | Pump | Tooltip shown |
| W-SRO-058 | search_replace_overlay.dart | Tooltip | Verify Replace tooltip | Hover | Pump | Tooltip shown |
| W-SRO-059 | search_replace_overlay.dart | Tooltip | Verify Close tooltip | Hover | Pump | Tooltip shown |
| W-SRO-060 | search_replace_overlay.dart | Tooltip | Verify Case tooltip | Hover | Pump | Tooltip shown |
| W-SRO-061 | search_replace_overlay.dart | Tooltip | Verify Regex tooltip | Hover | Pump | Tooltip shown |

### Boundary & Lifecycle

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-SRO-062 | search_replace_overlay.dart | Lifecycle | Rebuild with identical parameters | Parent rebuild | pump | State preserved |
| W-SRO-063 | search_replace_overlay.dart | Lifecycle | Rebuild while expanded | Expand replace | Parent rebuild | Expanded state retained |
| W-SRO-064 | search_replace_overlay.dart | Boundary | Very long search query | 2000 chars | Pump | No overflow |
| W-SRO-065 | search_replace_overlay.dart | Boundary | Very long replace text | 2000 chars | Enter | No exception |
| W-SRO-066 | search_replace_overlay.dart | Boundary | Large match count | total=999999 | Pump | Counter displayed correctly |
| W-SRO-067 | search_replace_overlay.dart | Boundary | Rapid toggle of replace panel | Tap toggle repeatedly | Pump | No exception |
| W-SRO-068 | search_replace_overlay.dart | Boundary | Rapid typing | Simulate fast input | Pump | Stable callbacks |
| W-SRO-069 | search_replace_overlay.dart | Boundary | Rapid Enter presses | Multiple Enter | Pump | Navigation callbacks remain consistent |
| W-SRO-070 | search_replace_overlay.dart | Golden | Default overlay appearance | Pump widget | Golden comparison | Matches baseline |
| W-SRO-071 | search_replace_overlay.dart | Golden | Expanded replace section | Expand | Golden comparison | Matches baseline |
| W-SRO-072 | search_replace_overlay.dart | Golden | Preview mode appearance | Preview=true | Golden comparison | Matches baseline |
| W-SRO-073 | search_replace_overlay.dart | Golden | No-results appearance | Query + zero matches | Golden comparison | Matches baseline |

---

## Coverage Notes

### Expected Coverage

This file should realistically achieve **95–100% widget coverage**.

### Critical Branches Covered

- ✅ `initState()`
- ✅ `didUpdateWidget()` (both update and no-update branches)
- ✅ `dispose()`
- ✅ Preview mode enabled/disabled
- ✅ Replace section expanded/collapsed
- ✅ Search empty/non-empty
- ✅ Matches available/unavailable
- ✅ Previous enabled/disabled
- ✅ Next enabled/disabled
- ✅ Case-sensitive toggle (true/false)
- ✅ Regex toggle (true/false)
- ✅ Drag handle present/absent
- ✅ All keyboard shortcuts
- ✅ All callback paths
- ✅ No-results banner branches
- ✅ Tooltip rendering
- ✅ Boundary conditions
- ✅ Golden UI verification

### High-Value Tests

If time is limited, prioritize:

1. W-SRO-005 (`didUpdateWidget()`)
2. W-SRO-027 to W-SRO-031 (keyboard shortcuts)
3. W-SRO-032 to W-SRO-042 (replace workflow)
4. W-SRO-043 to W-SRO-048 (toggle branches)
5. W-SRO-049 to W-SRO-051 (no-results branches)
6. W-SRO-052 to W-SRO-054 (drag support)
7. W-SRO-062 to W-SRO-063 (state preservation)

These tests exercise the majority of the branching logic in the widget and provide the biggest coverage gains. :contentReference[oaicite:0]{index=0}