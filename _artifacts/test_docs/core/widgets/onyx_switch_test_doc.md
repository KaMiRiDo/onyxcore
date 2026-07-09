## Unit Test Plan

> N/A - `OnyxSwitch` is a pure presentation widget with no business logic. All meaningful coverage can be achieved through widget tests.

---

## Widget Test Plan

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---------|--------------------|-----------------------|-------------------------|-----------------------|---------------|-------------------|
| W-SWT-01 | onyx_switch.dart | OnyxSwitch | Render successfully with value=true | value=true | pumpWidget() | Finds one OnyxSwitch |
| W-SWT-02 | onyx_switch.dart | OnyxSwitch | Render successfully with value=false | value=false | pumpWidget() | Finds one OnyxSwitch |
| W-SWT-03 | onyx_switch.dart | GestureDetector | Toggle from false to true when tapped | value=false | Tap switch | Verify callback invoked once with true |
| W-SWT-04 | onyx_switch.dart | GestureDetector | Toggle from true to false when tapped | value=true | Tap switch | Verify callback invoked once with false |
| W-SWT-05 | onyx_switch.dart | GestureDetector | Invoke callback exactly once per tap | Mock callback | Single tap | Verify callback count == 1 |
| W-SWT-06 | onyx_switch.dart | GestureDetector | Invoke callback on every tap | Mock callback | Triple tap | Verify callback count == 3 |
| W-SWT-07 | onyx_switch.dart | AnimatedContainer | Render fixed width of 44 | Pump widget | Inspect AnimatedContainer | Width == 44 |
| W-SWT-08 | onyx_switch.dart | AnimatedContainer | Render fixed height of 24 | Pump widget | Inspect AnimatedContainer | Height == 24 |
| W-SWT-09 | onyx_switch.dart | AnimatedContainer | Use animation duration of 250ms | Pump widget | Inspect widget | Duration == 250ms |
| W-SWT-10 | onyx_switch.dart | AnimatedContainer | Use Curves.easeInOut | Pump widget | Inspect widget | Curve == easeInOut |
| W-SWT-11 | onyx_switch.dart | BoxDecoration | Apply primary gradient when enabled | value=true | Pump widget | Decoration.gradient == AppTheme.primaryGradient |
| W-SWT-12 | onyx_switch.dart | BoxDecoration | Remove gradient when disabled | value=false | Pump widget | Decoration.gradient == null |
| W-SWT-13 | onyx_switch.dart | BoxDecoration | Apply fallback color when disabled | value=false | Pump widget | Decoration.color == Colors.white.withAlpha(20) |
| W-SWT-14 | onyx_switch.dart | BoxDecoration | Remove fallback color when enabled | value=true | Pump widget | Decoration.color == null |
| W-SWT-15 | onyx_switch.dart | BoxDecoration | Apply border radius of 12 | Pump widget | Inspect decoration | BorderRadius.circular(12) |
| W-SWT-16 | onyx_switch.dart | Padding | Apply padding of 2 on all sides | Pump widget | Inspect Padding | EdgeInsets.all(2) |
| W-SWT-17 | onyx_switch.dart | AnimatedAlign | Align thumb to centerLeft when disabled | value=false | Pump widget | Alignment.centerLeft |
| W-SWT-18 | onyx_switch.dart | AnimatedAlign | Align thumb to centerRight when enabled | value=true | Pump widget | Alignment.centerRight |
| W-SWT-19 | onyx_switch.dart | AnimatedAlign | AnimatedAlign uses 250ms duration | Pump widget | Inspect AnimatedAlign | Duration == 250ms |
| W-SWT-20 | onyx_switch.dart | AnimatedAlign | AnimatedAlign uses easeInOut curve | Pump widget | Inspect AnimatedAlign | Curve == easeInOut |
| W-SWT-21 | onyx_switch.dart | Thumb Container | Render thumb with width 20 | Pump widget | Inspect Container | Width == 20 |
| W-SWT-22 | onyx_switch.dart | Thumb Container | Render thumb with height 20 | Pump widget | Inspect Container | Height == 20 |
| W-SWT-23 | onyx_switch.dart | Thumb Decoration | Thumb shape should be circle | Pump widget | Inspect decoration | Shape == BoxShape.circle |
| W-SWT-24 | onyx_switch.dart | Thumb Decoration | Thumb color should be white | Pump widget | Inspect decoration | Color == Colors.white |
| W-SWT-25 | onyx_switch.dart | Animation | Animate thumb from left to right | Stateful wrapper | Change value false→true | AnimatedAlign updates correctly |
| W-SWT-26 | onyx_switch.dart | Animation | Animate thumb from right to left | Stateful wrapper | Change value true→false | AnimatedAlign updates correctly |
| W-SWT-27 | onyx_switch.dart | Animation | Animate decoration when enabled | Stateful wrapper | Toggle value | Gradient applied after rebuild |
| W-SWT-28 | onyx_switch.dart | Animation | Animate decoration when disabled | Stateful wrapper | Toggle value | Background color restored |
| W-SWT-29 | onyx_switch.dart | Rebuild | Rebuild without value change | Parent rebuild | setState() | Widget remains stable |
| W-SWT-30 | onyx_switch.dart | Rebuild | Preserve state after multiple rebuilds | Parent rebuild multiple times | pump() | No visual regression |
| W-SWT-31 | onyx_switch.dart | GestureDetector | Rapid repeated taps | Mock callback | Tap 10 times | Callback invoked 10 times |
| W-SWT-32 | onyx_switch.dart | GestureDetector | Long press should not trigger callback | Mock callback | LongPress | Callback never invoked |
| W-SWT-33 | onyx_switch.dart | GestureDetector | Drag gesture should not trigger callback | Mock callback | Drag gesture | Callback never invoked |
| W-SWT-34 | onyx_switch.dart | GestureDetector | Tap outside switch should not trigger callback | Mock callback | Tap outside bounds | Callback never invoked |
| W-SWT-35 | onyx_switch.dart | GestureDetector | Double tap invokes callback twice | Mock callback | Double tap | Callback count == 2 |
| W-SWT-36 | onyx_switch.dart | Accessibility | Widget renders inside MaterialApp | Wrap with MaterialApp | pumpWidget() | No exception |
| W-SWT-37 | onyx_switch.dart | Accessibility | Widget renders inside Scaffold | Wrap with Scaffold | pumpWidget() | No exception |
| W-SWT-38 | onyx_switch.dart | Layout | Render inside Row | Pump Row | No overflow |
| W-SWT-39 | onyx_switch.dart | Layout | Render inside Column | Pump Column | No overflow |
| W-SWT-40 | onyx_switch.dart | Layout | Render inside ListView | Pump ListView | No exception |
| W-SWT-41 | onyx_switch.dart | Layout | Render inside Dialog | Pump AlertDialog | Widget displayed correctly |
| W-SWT-42 | onyx_switch.dart | Layout | Render inside Stack | Pump Stack | Widget displayed correctly |
| W-SWT-43 | onyx_switch.dart | Lifecycle | Remove widget after animation | Replace with SizedBox | pumpWidget() | No ticker or animation exception |
| W-SWT-44 | onyx_switch.dart | Lifecycle | Dispose after rapid rebuilds | Multiple rebuilds then remove | pumpWidget() | No FlutterError |
| W-SWT-45 | onyx_switch.dart | Theme | Render under light theme | MaterialApp(theme: ThemeData.light()) | pumpWidget() | No exception |
| W-SWT-46 | onyx_switch.dart | Theme | Render under dark theme | MaterialApp(theme: ThemeData.dark()) | pumpWidget() | No exception |
| W-SWT-47 | onyx_switch.dart | Boundary | Pump 100 switches simultaneously | GridView with 100 switches | pumpWidget() | All widgets render successfully |
| W-SWT-48 | onyx_switch.dart | Boundary | Alternate enabled/disabled switches | Multiple switches | pumpWidget() | Correct alignment and decoration for each |
| W-SWT-49 | onyx_switch.dart | Golden | Verify enabled appearance | value=true | Capture golden | Matches approved image |
| W-SWT-50 | onyx_switch.dart | Golden | Verify disabled appearance | value=false | Capture golden | Matches approved image |

---

## Coverage Notes

### Expected Coverage

This file should achieve **100% coverage** with the above tests.

### Important Coverage Points

- ✅ `build()` method
- ✅ Both branches of `value ? ... : ...` for:
  - Gradient
  - Background color
  - Thumb alignment
  - Callback toggle value
- ✅ Animation configuration
- ✅ Gesture handling
- ✅ Decoration properties
- ✅ Layout constants
- ✅ Widget rebuilds
- ✅ Lifecycle (removal/rebuild)
- ✅ Boundary conditions
- ✅ Golden rendering

### Optional Improvements

No production changes are required. The widget is already highly testable because it:
- Has no external dependencies.
- Uses constructor injection for state.
- Contains deterministic UI logic.
- Has no asynchronous operations or platform-specific code.