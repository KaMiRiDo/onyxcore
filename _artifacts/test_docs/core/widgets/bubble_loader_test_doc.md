## Unit Test Plan

> N/A - `BubbleLoader` is a presentation widget. The only non-widget logic is inside `BubblePainter`, which is best exercised through widget tests and direct painter tests rather than isolated unit tests.

---

# Widget Test Plan

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---------|--------------------|-----------------------|-------------------------|-----------------------|---------------|-------------------|
| W-BUB-01 | bubble_loader.dart | BubbleLoader | Render successfully with default constructor | Pump `BubbleLoader()` | pump() | Finds one BubbleLoader |
| W-BUB-02 | bubble_loader.dart | BubbleLoader | Render with custom size | size = 120 | pump() | SizedBox width & height == 120 |
| W-BUB-03 | bubble_loader.dart | BubbleLoader | Default size should be 80 | Default constructor | pump() | SizedBox dimensions == 80 |
| W-BUB-04 | bubble_loader.dart | BubbleLoader | Wrap widget inside Center | Pump widget | pump() | Finds Center ancestor |
| W-BUB-05 | bubble_loader.dart | BubbleLoader | Create AnimatedBuilder | Pump widget | pump() | Finds AnimatedBuilder |
| W-BUB-06 | bubble_loader.dart | BubbleLoader | Create CustomPaint | Pump widget | pump() | Finds CustomPaint |
| W-BUB-07 | bubble_loader.dart | BubbleLoader | Create BubblePainter | Pump widget | Inspect painter | Painter is BubblePainter |
| W-BUB-08 | bubble_loader.dart | initState() | Create AnimationController | Pump widget | pump() | No exception |
| W-BUB-09 | bubble_loader.dart | initState() | Start repeating animation automatically | Pump widget | pump(Duration(milliseconds:500)) | Painter rebuilt |
| W-BUB-10 | bubble_loader.dart | dispose() | Dispose AnimationController safely | Replace BubbleLoader with SizedBox | pumpWidget() | No FlutterError |
| W-BUB-11 | bubble_loader.dart | Animation | Continue animating over multiple frames | Pump widget | pump several frames | No exceptions |
| W-BUB-12 | bubble_loader.dart | Animation | Continue after one full animation cycle | Pump(Duration(seconds:2)) | pump | Animation still active |
| W-BUB-13 | bubble_loader.dart | Animation | Continue after multiple cycles | Pump(Duration(seconds:10)) | pump | Widget stable |
| W-BUB-14 | bubble_loader.dart | BubblePainter | Paint without throwing for progress=0.0 | Instantiate BubblePainter | paint() | No exception |
| W-BUB-15 | bubble_loader.dart | BubblePainter | Paint without throwing for progress=0.5 | Painter(progress:0.5) | paint() | No exception |
| W-BUB-16 | bubble_loader.dart | BubblePainter | Paint without throwing for progress=1.0 | Painter(progress:1.0) | paint() | No exception |
| W-BUB-17 | bubble_loader.dart | BubblePainter | Paint for progress very close to zero | progress=0.000001 | paint() | No exception |
| W-BUB-18 | bubble_loader.dart | BubblePainter | Paint for progress very close to one | progress=0.999999 | paint() | No exception |
| W-BUB-19 | bubble_loader.dart | BubblePainter | Paint using tiny canvas | Canvas Size(1,1) | paint() | No exception |
| W-BUB-20 | bubble_loader.dart | BubblePainter | Paint using large canvas | Canvas Size(1000,1000) | paint() | No exception |
| W-BUB-21 | bubble_loader.dart | BubblePainter | Paint using rectangular canvas | Size(300,120) | paint() | No exception |
| W-BUB-22 | bubble_loader.dart | BubblePainter | Paint using zero width | Size.zero | paint() | No exception |
| W-BUB-23 | bubble_loader.dart | BubblePainter | Paint using zero height | Size(100,0) | paint() | No exception |
| W-BUB-24 | bubble_loader.dart | BubblePainter | Paint using custom color | Color.red | paint() | No exception |
| W-BUB-25 | bubble_loader.dart | BubblePainter | shouldRepaint always returns true for identical painter | Two equal painters | shouldRepaint() | Returns true |
| W-BUB-26 | bubble_loader.dart | BubblePainter | shouldRepaint returns true for different progress | progress differs | shouldRepaint() | true |
| W-BUB-27 | bubble_loader.dart | BubblePainter | shouldRepaint returns true for different colors | color differs | shouldRepaint() | true |
| W-BUB-28 | bubble_loader.dart | BubbleLoader | Rebuild after parent rebuild | Wrap in StatefulBuilder | setState() | Widget rebuilds |
| W-BUB-29 | bubble_loader.dart | BubbleLoader | Change size dynamically | Parent changes size 80→120 | pump() | SizedBox updates |
| W-BUB-30 | bubble_loader.dart | BubbleLoader | Preserve animation after rebuild | Trigger parent rebuild | pump() | Animation continues |
| W-BUB-31 | bubble_loader.dart | BubbleLoader | Remove widget during animation | Pump then replace | pumpWidget() | No ticker leak |
| W-BUB-32 | bubble_loader.dart | BubbleLoader | Multiple BubbleLoader instances simultaneously | Pump Column with 3 loaders | pump() | Three CustomPaint widgets |
| W-BUB-33 | bubble_loader.dart | BubbleLoader | Different sizes simultaneously | 40,80,160 | pump() | Each SizedBox matches size |
| W-BUB-34 | bubble_loader.dart | BubblePainter | Paint repeatedly 100 frames | Loop paint() | No exception |
| W-BUB-35 | bubble_loader.dart | BubblePainter | Paint with progress increments of 0.125 | Loop progress values | paint() | Stable output |
| W-BUB-36 | bubble_loader.dart | BubblePainter | Paint at every bubble phase offset | progress values matching bubble offsets | paint() | No exception |
| W-BUB-37 | bubble_loader.dart | BubblePainter | Verify painter handles negative progress gracefully (defensive) | progress=-0.5 | paint() | No exception |
| W-BUB-38 | bubble_loader.dart | BubblePainter | Verify painter handles progress>1 gracefully | progress=1.5 | paint() | No exception |
| W-BUB-39 | bubble_loader.dart | BubbleLoader | Works inside ScrollView | Wrap in ListView | pump() | Widget renders |
| W-BUB-40 | bubble_loader.dart | BubbleLoader | Works inside Stack | Wrap in Stack | pump() | Widget renders |
| W-BUB-41 | bubble_loader.dart | BubbleLoader | Works inside Dialog | Pump AlertDialog | pump() | Widget renders |
| W-BUB-42 | bubble_loader.dart | BubbleLoader | Works inside Overlay | OverlayEntry | pump() | Widget renders |
| W-BUB-43 | bubble_loader.dart | BubbleLoader | Dark theme compatibility | MaterialApp darkTheme | pump() | No exception |
| W-BUB-44 | bubble_loader.dart | BubbleLoader | Light theme compatibility | MaterialApp theme | pump() | No exception |
| W-BUB-45 | bubble_loader.dart | BubbleLoader | Hot rebuild during animation | Rebuild parent several times | pump() | Stable |
| W-BUB-46 | bubble_loader.dart | BubbleLoader | Remove and recreate widget | Dispose then recreate | pumpWidget() | New controller created |
| W-BUB-47 | bubble_loader.dart | BubblePainter | Paint 100 consecutive frames | Loop progress 0→1 | paint() | No exception |
| W-BUB-48 | bubble_loader.dart | BubblePainter | Bubble radius never becomes NaN | Multiple progress values | paint() | No exception |
| W-BUB-49 | bubble_loader.dart | BubblePainter | Bubble offsets remain finite | Various canvas sizes | paint() | No exception |
| W-BUB-50 | bubble_loader.dart | BubbleLoader | Golden test for default appearance | Pump widget | Compare golden | Golden matches baseline |

---

## Coverage Notes

### Expected Coverage

This file should realistically reach **95–100%**.

Remaining uncovered lines, if any, would likely be Flutter framework internals rather than your own code.

### Recommended Golden Tests

- Default 80px loader
- 120px loader
- Progress at 0%
- Progress at 50%
- Progress at 100%

### Potential Improvements (Optional)

The following change would make the widget even more testable:

```dart
const BubbleLoader({
  super.key,
  this.size = 80,
  this.duration = const Duration(milliseconds: 2000),
});

final Duration duration;
```

This would allow injecting a shorter animation duration during tests for faster execution.