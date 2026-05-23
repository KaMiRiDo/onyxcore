# Playing EQ Animation Test Document

### 1. Unit Test Plan Format
N/A - Pure Presentation Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-EQ-01 | playing_eq_animation.dart | PlayingEqAnimation | render exactly 3 animated bars | Render PlayingEqAnimation | Mount widget | Finds exactly 3 _EqBar widgets in a Row |
| W-AUD-EQ-02 | playing_eq_animation.dart | PlayingEqAnimation | start animation controller immediately on mount | Render PlayingEqAnimation | Wait 100ms | verify AnimationController is animating (isAnimating=true) |
| W-AUD-EQ-03 | playing_eq_animation.dart | PlayingEqAnimation | use 600ms animation duration | Render PlayingEqAnimation | Mount widget | verify AnimationController.duration is Duration(milliseconds: 600) |
| W-AUD-EQ-04 | playing_eq_animation.dart | PlayingEqAnimation | repeat animation with reverse | Render PlayingEqAnimation | Wait 1200ms (2 full cycles) | verify animation repeats (controller.repeat(reverse: true)) |
| W-AUD-EQ-05 | playing_eq_animation.dart | PlayingEqAnimation | render within 16x16 SizedBox | Render PlayingEqAnimation | Mount widget | Finds SizedBox with width=16, height=16 |
| W-AUD-EQ-06 | playing_eq_animation.dart | PlayingEqAnimation | align bars to bottom with spaceEvenly distribution | Render PlayingEqAnimation | Mount widget | verify Row has crossAxisAlignment=CrossAxisAlignment.end, mainAxisAlignment=MainAxisAlignment.spaceEvenly |
| W-AUD-EQ-07 | playing_eq_animation.dart | PlayingEqAnimation | use phase offsets 0.0, 0.3, 0.6 for three bars | Render PlayingEqAnimation | Mount widget | verify _EqBar widgets have offset values 0.0, 0.3, 0.6 |
| W-AUD-EQ-08 | playing_eq_animation.dart | PlayingEqAnimation | render bars with AppColors.magenta color | Render PlayingEqAnimation, wait for frame | Render widget | verify bar Container decoration color is AppColors.magenta |
| W-AUD-EQ-09 | playing_eq_animation.dart | PlayingEqAnimation | render bars with 3px width | Render PlayingEqAnimation | Mount widget | verify each bar Container has width=3 |
| W-AUD-EQ-10 | playing_eq_animation.dart | PlayingEqAnimation | render bars with 2px border radius | Render PlayingEqAnimation | Mount widget | verify bar Container borderRadius is Radius.circular(2) |
| W-AUD-EQ-11 | playing_eq_animation.dart | _EqBar | calculate bar height between 4px and 12px | Render _EqBar with various animation values (0.0 to 1.0) | Pump animation | verify height formula: 4.0 + (sin(value * pi) * 8.0), bounded [4, 12] |
| W-AUD-EQ-12 | playing_eq_animation.dart | _EqBar | produce different heights at different offsets at same animation value | Render 3 bars with offsets 0.0, 0.3, 0.6 at same controller value | Mount widget | verify all 3 bars have different heights due to phase shift |
| W-AUD-EQ-13 | playing_eq_animation.dart | PlayingEqAnimation | dispose AnimationController on unmount | Mount then unmount PlayingEqAnimation | Unmount widget | verify AnimationController is disposed (no tickers leaking) |
| W-AUD-EQ-14 | playing_eq_animation.dart | _EqBar | use AnimatedBuilder for efficient rebuilds | Render _EqBar | Mount widget | Finds AnimatedBuilder widget wrapping the Container |
| W-AUD-EQ-15 | playing_eq_animation.dart | _EqBar | apply modulo wrap (% 1.0) to shifted value | Set animation.value=0.8, offset=0.6 | Evaluate height | verify shifted value is (0.8+0.6)%1.0 = 0.4, height uses sin(0.4*pi) |
