# Playing EQ Animation Test Document

### 1. Unit Test Plan Format
N/A - Pure Presentation Logic

### 2. Widget Test Plan Format
| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| W-AUD-EQ-01 | playing_eq_animation.dart | PlayingEqAnimation | render animated bars when playing | Render widget with isPlaying=true | Wait 100ms | verify animation controllers are active, bars change height |
| W-AUD-EQ-02 | playing_eq_animation.dart | PlayingEqAnimation | render static bars when paused | Render widget with isPlaying=false | Wait 100ms | verify animation controllers are stopped |
| W-AUD-EQ-03 | playing_eq_animation.dart | PlayingEqAnimation | pause animation when isPlaying changes to false | Render widget (isPlaying=true), then update to false | Update widget | verify controllers stop |
