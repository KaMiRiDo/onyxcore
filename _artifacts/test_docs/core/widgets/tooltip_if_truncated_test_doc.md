## Unit Test Plan

> N/A - `TooltipIfTruncated` is a pure presentation widget whose behavior depends on Flutter layout constraints (`LayoutBuilder`, `TextPainter`, and `Tooltip`). All meaningful coverage should be achieved through widget tests.

---

## Widget Test Plan

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---------|--------------------|-----------------------|-------------------------|-----------------------|---------------|-------------------|
| W-TTT-001 | tooltip_if_truncated.dart | TooltipIfTruncated | Render successfully with required parameters | text="Hello" | pumpWidget() | Widget renders without exception |
| W-TTT-002 | tooltip_if_truncated.dart | TooltipIfTruncated | Render default Text widget | Short text | Pump | Finds one Text widget |
| W-TTT-003 | tooltip_if_truncated.dart | TooltipIfTruncated | Apply default maxLines=1 | Default constructor | Pump | Text.maxLines == 1 |
| W-TTT-004 | tooltip_if_truncated.dart | TooltipIfTruncated | Apply custom maxLines | maxLines=3 | Pump | Text.maxLines == 3 |
| W-TTT-005 | tooltip_if_truncated.dart | TooltipIfTruncated | Apply supplied TextStyle | Custom TextStyle | Pump | Text.style matches supplied style |

### Non-Truncated Path

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup & Mocks | Action | Assertions |
|---------|--------------------|-----------------------|----------|---------------|--------|------------|
| W-TTT-006 | tooltip_if_truncated.dart | LayoutBuilder | Render plain Text when text fits | Wide constraints | Pump | Tooltip absent |
| W-TTT-007 | tooltip_if_truncated.dart | LayoutBuilder | Do not wrap Text in Tooltip | Wide width | Pump | Finds Text only |
| W-TTT-008 | tooltip_if_truncated.dart | Text | Display original text | Short string | Pump | Text displayed correctly |
| W-TTT-009 | tooltip_if_truncated.dart | Text | Apply TextOverflow.ellipsis | Short text | Pump | overflow == ellipsis |
| W-TTT-010 | tooltip_if_truncated.dart | LayoutBuilder | Correctly determine non-truncated state | Large width | Pump | didExceedMaxLines == false branch executed |

### Truncated Path

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup & Mocks | Action | Assertions |
|---------|--------------------|-----------------------|----------|---------------|--------|------------|
| W-TTT-011 | tooltip_if_truncated.dart | LayoutBuilder | Wrap text inside Tooltip when truncated | Very narrow constraints | Pump | Tooltip rendered |
| W-TTT-012 | tooltip_if_truncated.dart | Tooltip | Display tooltip after hover | Truncated text | Hover | Tooltip visible |
| W-TTT-013 | tooltip_if_truncated.dart | Tooltip | Preserve child Text widget | Truncated text | Pump | Text still visible |
| W-TTT-014 | tooltip_if_truncated.dart | Tooltip | Tooltip child uses WidgetSpan | Truncated text | Pump | richMessage contains WidgetSpan |
| W-TTT-015 | tooltip_if_truncated.dart | Tooltip | Tooltip waitDuration is 500ms | Truncated | Inspect | waitDuration == 500ms |
| W-TTT-016 | tooltip_if_truncated.dart | Tooltip | Tooltip uses constrained container | Truncated | Pump | maxWidth == 320 |
| W-TTT-017 | tooltip_if_truncated.dart | Tooltip | Tooltip container uses horizontal padding=4 | Truncated | Pump | Padding correct |
| W-TTT-018 | tooltip_if_truncated.dart | Tooltip | Tooltip container uses vertical padding=2 | Truncated | Pump | Padding correct |
| W-TTT-019 | tooltip_if_truncated.dart | Tooltip | Tooltip text is soft wrapped | Truncated | Pump | softWrap == true |

### Tooltip Message

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TTT-020 | tooltip_if_truncated.dart | Tooltip | Display original text when tooltipMessage is null | tooltipMessage=null | Hover | Tooltip shows original text |
| W-TTT-021 | tooltip_if_truncated.dart | Tooltip | Display custom tooltipMessage | tooltipMessage="Custom" | Hover | Tooltip shows custom text |
| W-TTT-022 | tooltip_if_truncated.dart | Tooltip | Ignore original text when tooltipMessage provided | Custom tooltip | Hover | Original text not shown in tooltip |
| W-TTT-023 | tooltip_if_truncated.dart | Tooltip | Display unicode tooltip message | Malayalam/Japanese | Hover | Unicode rendered correctly |
| W-TTT-024 | tooltip_if_truncated.dart | Tooltip | Display multiline tooltip | Tooltip contains \\n | Hover | Multiple lines rendered |

### Tooltip TextStyle

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TTT-025 | tooltip_if_truncated.dart | Tooltip | Use Theme tooltip textStyle when available | ThemeData.tooltipTheme.textStyle | Hover | Theme style applied |
| W-TTT-026 | tooltip_if_truncated.dart | Tooltip | Fall back to default TextStyle when theme style is null | Theme without tooltip style | Hover | Default style applied |
| W-TTT-027 | tooltip_if_truncated.dart | Tooltip | Override fontSize to 14 | Theme textStyle | Hover | fontSize == 14 |
| W-TTT-028 | tooltip_if_truncated.dart | Tooltip | Override height to 1.5 | Theme textStyle | Hover | height == 1.5 |
| W-TTT-029 | tooltip_if_truncated.dart | Tooltip | Override letterSpacing to 0.2 | Theme textStyle | Hover | letterSpacing == 0.2 |
| W-TTT-030 | tooltip_if_truncated.dart | Tooltip | Override fontWeight to w600 | Theme textStyle | Hover | fontWeight == FontWeight.w600 |
| W-TTT-031 | tooltip_if_truncated.dart | Tooltip | Override text color to white | Theme textStyle | Hover | color == Colors.white |

### Layout Variations

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TTT-032 | tooltip_if_truncated.dart | LayoutBuilder | Handle zero width constraints | SizedBox(width:0) | Pump | No exception |
| W-TTT-033 | tooltip_if_truncated.dart | LayoutBuilder | Handle extremely small width | Width=5 | Pump | Tooltip rendered |
| W-TTT-034 | tooltip_if_truncated.dart | LayoutBuilder | Handle large width | Width=1000 | Pump | Tooltip absent |
| W-TTT-035 | tooltip_if_truncated.dart | LayoutBuilder | Handle maxLines=2 | Narrow width | Pump | Correct truncation decision |
| W-TTT-036 | tooltip_if_truncated.dart | LayoutBuilder | Handle maxLines=5 | Long paragraph | Pump | Text behaves correctly |

### Rebuilds

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TTT-037 | tooltip_if_truncated.dart | Rebuild | Rebuild without property changes | Parent rebuild | pump() | Stable |
| W-TTT-038 | tooltip_if_truncated.dart | Rebuild | Update displayed text | Change text | Rebuild | New text shown |
| W-TTT-039 | tooltip_if_truncated.dart | Rebuild | Update TextStyle | New style | Rebuild | Style updated |
| W-TTT-040 | tooltip_if_truncated.dart | Rebuild | Update tooltipMessage | New tooltip | Hover | Updated tooltip shown |
| W-TTT-041 | tooltip_if_truncated.dart | Rebuild | Update maxLines | Change maxLines | Rebuild | Layout recalculated |

### Boundary Conditions

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TTT-042 | tooltip_if_truncated.dart | Boundary | Empty string | text="" | Pump | No exception |
| W-TTT-043 | tooltip_if_truncated.dart | Boundary | Very long string | 5000 characters | Pump | Tooltip rendered |
| W-TTT-044 | tooltip_if_truncated.dart | Boundary | Unicode string | Malayalam/Japanese | Pump | Text displayed |
| W-TTT-045 | tooltip_if_truncated.dart | Boundary | Emoji string | 😀🚀🔥 | Pump | Emojis rendered |
| W-TTT-046 | tooltip_if_truncated.dart | Boundary | Whitespace-only string | "     " | Pump | No exception |
| W-TTT-047 | tooltip_if_truncated.dart | Boundary | Text containing newline characters | Multi-line text | Pump | Correct layout |
| W-TTT-048 | tooltip_if_truncated.dart | Boundary | Extremely large tooltipMessage | 5000 chars | Hover | Tooltip renders |
| W-TTT-049 | tooltip_if_truncated.dart | Boundary | Long unbreakable word | Single 300-char word | Pump | Tooltip rendered |
| W-TTT-050 | tooltip_if_truncated.dart | Boundary | Rapid parent rebuilds | Multiple setState() | Pump | Stable |

### Golden Tests

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TTT-051 | tooltip_if_truncated.dart | Golden | Short text | Wide width | Capture | Matches golden |
| W-TTT-052 | tooltip_if_truncated.dart | Golden | Truncated text | Narrow width | Capture | Matches golden |
| W-TTT-053 | tooltip_if_truncated.dart | Golden | Multi-line text | maxLines=2 | Capture | Matches golden |
| W-TTT-054 | tooltip_if_truncated.dart | Golden | Custom style | Styled text | Capture | Matches golden |
| W-TTT-055 | tooltip_if_truncated.dart | Golden | Long tooltip | Hover | Capture | Matches golden |

---

## Coverage Notes

### Expected Coverage

**100% widget coverage** is realistically achievable for this file.

### Critical Branches Covered

- ✅ `isTruncated == false`
- ✅ `isTruncated == true`
- ✅ `tooltipMessage ?? text`
- ✅ Theme tooltip style available
- ✅ Theme tooltip style unavailable (fallback style)
- ✅ Default `maxLines`
- ✅ Custom `maxLines`
- ✅ Custom `TextStyle`
- ✅ Default `TextStyle`
- ✅ LayoutBuilder execution
- ✅ Tooltip creation
- ✅ Text widget creation
- ✅ Rich tooltip rendering
- ✅ Boundary conditions
- ✅ Golden rendering

### High-Priority Coverage Tests

If you're optimizing for maximum coverage with minimal effort, prioritize:

1. **W-TTT-006** – Non-truncated branch
2. **W-TTT-011** – Truncated branch
3. **W-TTT-020** – `tooltipMessage == null`
4. **W-TTT-021** – Custom `tooltipMessage`
5. **W-TTT-025** – Theme textStyle branch
6. **W-TTT-026** – Fallback textStyle branch
7. **W-TTT-038** – Rebuild with new text
8. **W-TTT-041** – Rebuild with different `maxLines`

These tests cover virtually every decision point in `TooltipIfTruncated`, including both rendering paths, style selection, tooltip content selection, and rebuild behavior. :contentReference[oaicite:0]{index=0}