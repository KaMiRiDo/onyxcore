## Unit Test Plan

> N/A - `ToastHelper` is primarily responsible for managing `OverlayEntry`, animations, timers, and widget rendering. The helper itself is tightly coupled to Flutter framework APIs, making widget tests the appropriate choice. The only direct logic (`_TrianglePainter.shouldRepaint`) can also be covered via widget/direct painter tests.

---

## Widget Test Plan

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---------|--------------------|-----------------------|-------------------------|-----------------------|---------------|-------------------|
| W-TOA-001 | toast_helper.dart | ToastHelper.show() | Display toast successfully | Valid BuildContext with Overlay | Call show() | OverlayEntry inserted |
| W-TOA-002 | toast_helper.dart | ToastHelper.show() | Use Overlay from BuildContext when available | Overlay exists | Call show() | Toast appears in local overlay |
| W-TOA-003 | toast_helper.dart | ToastHelper.show() | Fall back to appNavigatorKey overlay when context overlay is null | Mock navigator overlay | Call show() | Toast appears using navigator overlay |
| W-TOA-004 | toast_helper.dart | ToastHelper.show() | Return gracefully when no overlay exists | Context without overlay | Call show() | No exception |
| W-TOA-005 | toast_helper.dart | ToastHelper.show() | Remove previous toast before showing new one | Existing toast visible | Call show() again | Previous OverlayEntry removed |
| W-TOA-006 | toast_helper.dart | ToastHelper.show() | Cancel previous timer before creating a new toast | Existing timer running | Call show() again | Previous timer cancelled |
| W-TOA-007 | toast_helper.dart | ToastHelper.show() | Replace toast message | Existing toast | Show second toast | New message displayed |
| W-TOA-008 | toast_helper.dart | ToastHelper.show() | Replace icon | Existing toast | Show second toast | New icon displayed |
| W-TOA-009 | toast_helper.dart | ToastHelper.show() | Replace error state | Existing success toast | Show error toast | Error styling applied |
| W-TOA-010 | toast_helper.dart | ToastHelper.show() | Auto-dismiss toast after 4 seconds | Toast displayed | pump(Duration(seconds:4)) | Overlay removed |
| W-TOA-011 | toast_helper.dart | ToastHelper.show() | Keep toast visible before timeout | Toast displayed | pump(Duration(seconds:3)) | Overlay still visible |
| W-TOA-012 | toast_helper.dart | ToastHelper.show() | Remove overlay only once after timer | Toast visible | Wait >4s | No duplicate removal exception |

### Toast Widget Rendering

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TOA-013 | toast_helper.dart | _ToastWidget | Render successfully | Default values | Pump | Widget renders |
| W-TOA-014 | toast_helper.dart | _ToastWidget | Render success toast | isError=false | Pump | Success styling shown |
| W-TOA-015 | toast_helper.dart | _ToastWidget | Render error toast | isError=true | Pump | Error styling shown |
| W-TOA-016 | toast_helper.dart | _ToastWidget | Display supplied message | "Hello" | Pump | Text visible |
| W-TOA-017 | toast_helper.dart | _ToastWidget | Display custom icon | Icons.save | Pump | Save icon visible |
| W-TOA-018 | toast_helper.dart | _ToastWidget | Use default success icon when icon=null | isError=false | Pump | Info icon shown |
| W-TOA-019 | toast_helper.dart | _ToastWidget | Use default error icon when icon=null | isError=true | Pump | Error icon shown |
| W-TOA-020 | toast_helper.dart | _ToastWidget | Wrap content inside FadeTransition | Pump | Inspect | FadeTransition exists |
| W-TOA-021 | toast_helper.dart | _ToastWidget | Wrap content inside SlideTransition | Pump | Inspect | SlideTransition exists |
| W-TOA-022 | toast_helper.dart | _ToastWidget | Render BackdropFilter | Pump | Inspect | BackdropFilter present |
| W-TOA-023 | toast_helper.dart | _ToastWidget | Render ClipRRect | Pump | Inspect | ClipRRect exists |
| W-TOA-024 | toast_helper.dart | _ToastWidget | Render CustomPaint notch | Pump | Inspect | CustomPaint rendered |
| W-TOA-025 | toast_helper.dart | _ToastWidget | Render Row containing icon and message | Pump | Inspect | Row contains Icon & Text |

### Animation

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TOA-026 | toast_helper.dart | initState() | Create AnimationController | Pump | Pump | No exception |
| W-TOA-027 | toast_helper.dart | initState() | Forward animation starts automatically | Pump | pump(Duration(milliseconds:150)) | Animation progresses |
| W-TOA-028 | toast_helper.dart | Animation | Complete fade animation | Pump | pump(Duration(milliseconds:300)) | Animation completed |
| W-TOA-029 | toast_helper.dart | Animation | Complete slide animation | Pump | pump(Duration(milliseconds:300)) | Offset reaches zero |
| W-TOA-030 | toast_helper.dart | dispose() | Dispose AnimationController safely | Remove widget | Pump | No ticker leak |

### Error / Success Styling

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TOA-031 | toast_helper.dart | Success Style | Apply primary gradient | isError=false | Pump | Gradient applied |
| W-TOA-032 | toast_helper.dart | Success Style | Use violet icon color | Success | Pump | Icon color correct |
| W-TOA-033 | toast_helper.dart | Success Style | Apply violet border | Success | Pump | Border color correct |
| W-TOA-034 | toast_helper.dart | Error Style | Remove gradient | isError=true | Pump | Gradient null |
| W-TOA-035 | toast_helper.dart | Error Style | Apply error background | Error | Pump | Background correct |
| W-TOA-036 | toast_helper.dart | Error Style | Apply error border | Error | Pump | Border color correct |
| W-TOA-037 | toast_helper.dart | Error Style | Apply error icon color | Error | Pump | Icon color correct |

### Overlay Behavior

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TOA-038 | toast_helper.dart | OverlayEntry | Positioned at top=60 | Pump | Inspect | Top == 60 |
| W-TOA-039 | toast_helper.dart | OverlayEntry | Positioned at right=24 | Pump | Inspect | Right == 24 |
| W-TOA-040 | toast_helper.dart | OverlayEntry | Material uses transparent color | Pump | Inspect | Material transparent |
| W-TOA-041 | toast_helper.dart | OverlayEntry | Overlay removed after timer | Wait | Pump | Overlay absent |

### Triangle Painter

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TOA-042 | toast_helper.dart | _TrianglePainter | Paint without exception | Painter | paint() | No exception |
| W-TOA-043 | toast_helper.dart | _TrianglePainter | Paint with custom color | Error color | paint() | No exception |
| W-TOA-044 | toast_helper.dart | _TrianglePainter | Paint on tiny canvas | Size(2,2) | paint() | No exception |
| W-TOA-045 | toast_helper.dart | _TrianglePainter | Paint on large canvas | Size(100,50) | paint() | No exception |
| W-TOA-046 | toast_helper.dart | _TrianglePainter | shouldRepaint always returns false | Two painters | shouldRepaint() | false |

### Lifecycle

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TOA-047 | toast_helper.dart | Lifecycle | Rebuild toast widget | Parent rebuild | Pump | State retained |
| W-TOA-048 | toast_helper.dart | Lifecycle | Dispose while animation running | Remove widget early | Pump | No exception |
| W-TOA-049 | toast_helper.dart | Lifecycle | Dispose after animation complete | Remove widget | Pump | No exception |

### Boundary Conditions

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TOA-050 | toast_helper.dart | Boundary | Very long message | 2000 chars | Show toast | No overflow |
| W-TOA-051 | toast_helper.dart | Boundary | Empty message | "" | Show toast | Toast still renders |
| W-TOA-052 | toast_helper.dart | Boundary | Unicode message | Malayalam/Japanese | Show | Text rendered |
| W-TOA-053 | toast_helper.dart | Boundary | Multiple consecutive show() calls | Loop 20 times | Show repeatedly | Only final toast visible |
| W-TOA-054 | toast_helper.dart | Boundary | Rapid alternating success/error toasts | Alternate calls | Show repeatedly | Latest styling shown |
| W-TOA-055 | toast_helper.dart | Boundary | Custom icon with error=true | Error + Save icon | Show | Custom icon overrides default |
| W-TOA-056 | toast_helper.dart | Boundary | Custom icon with success | Success + Folder icon | Show | Folder icon rendered |

### Golden Tests

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TOA-057 | toast_helper.dart | Golden | Default success toast | Pump | Golden | Matches baseline |
| W-TOA-058 | toast_helper.dart | Golden | Error toast | Pump | Golden | Matches baseline |
| W-TOA-059 | toast_helper.dart | Golden | Success toast with custom icon | Pump | Golden | Matches baseline |
| W-TOA-060 | toast_helper.dart | Golden | Long message toast | Pump | Golden | Matches baseline |

---

## Coverage Notes

### Expected Coverage

This file should realistically achieve **98–100% widget coverage**.

### Critical Branches Covered

- ✅ Overlay available / unavailable
- ✅ Context overlay vs navigator overlay fallback
- ✅ Existing overlay removal
- ✅ Existing timer cancellation
- ✅ Timer auto-dismiss
- ✅ Success vs error styling
- ✅ Custom icon vs default icon
- ✅ Animation lifecycle (`initState` / `dispose`)
- ✅ Fade & slide transitions
- ✅ `_TrianglePainter.paint()`
- ✅ `_TrianglePainter.shouldRepaint()`
- ✅ Boundary conditions
- ✅ Golden rendering

### High-Priority Coverage Tests

To maximize coverage quickly, prioritize:

1. **W-TOA-003** – Navigator overlay fallback
2. **W-TOA-005** – Existing toast replacement
3. **W-TOA-006** – Timer cancellation
4. **W-TOA-010** – Auto-dismiss timer
5. **W-TOA-018 / W-TOA-019** – Default icon branches
6. **W-TOA-031 → W-TOA-037** – Success/error styling branches
7. **W-TOA-046** – `shouldRepaint()`
8. **W-TOA-053** – Rapid successive `show()` calls (covers static state handling)

These tests exercise nearly every branch in `ToastHelper.show()`, `_ToastWidget`, and `_TrianglePainter`, providing the highest practical coverage for this file. :contentReference[oaicite:0]{index=0}