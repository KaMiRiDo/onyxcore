## Unit Test Plan

> N/A - `TaskProgressButton` is a `ConsumerWidget` whose behavior is completely driven by Riverpod state and UI rendering. All meaningful coverage should be achieved through widget tests by overriding `taskProvider`.

---

## Widget Test Plan

| Test ID | File(s) Under Test | Target Widget / State | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---------|--------------------|-----------------------|-------------------------|-----------------------|---------------|-------------------|
| W-TPB-001 | task_progress_overlay.dart | TaskProgressButton | Render successfully | Override taskProvider with valid state | pumpWidget() | Widget renders without exception |
| W-TPB-002 | task_progress_overlay.dart | Empty State | Reserve IconButton space when no tasks exist | taskProvider=[] | Pump | Disabled IconButton rendered |
| W-TPB-003 | task_progress_overlay.dart | Empty State | Render placeholder SizedBox | taskProvider=[] | Pump | SizedBox(20x20) rendered |
| W-TPB-004 | task_progress_overlay.dart | Empty State | Disable IconButton | taskProvider=[] | Pump | onPressed == null |
| W-TPB-005 | task_progress_overlay.dart | Empty State | Hide progress indicator | taskProvider=[] | Pump | CircularProgressIndicator absent |
| W-TPB-006 | task_progress_overlay.dart | Empty State | Hide success icon | taskProvider=[] | Pump | Check icon absent |
| W-TPB-007 | task_progress_overlay.dart | Empty State | Hide error icon | taskProvider=[] | Pump | Error icon absent |

### Running Tasks

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup & Mocks | Action | Assertions |
|---------|--------------------|-----------------------|----------|---------------|--------|------------|
| W-TPB-008 | task_progress_overlay.dart | Running State | Show progress indicator when one running task exists | One running task | Pump | CircularProgressIndicator visible |
| W-TPB-009 | task_progress_overlay.dart | Running State | Hide success icon | Running task | Pump | Check icon absent |
| W-TPB-010 | task_progress_overlay.dart | Running State | Hide error icon | Running task | Pump | Error icon absent |
| W-TPB-011 | task_progress_overlay.dart | Running State | Display determinate progress | Progress=0.5 | Pump | Indicator.value==0.5 |
| W-TPB-012 | task_progress_overlay.dart | Running State | Display indeterminate progress for zero progress | Progress=0 | Pump | Indicator.value==null |
| W-TPB-013 | task_progress_overlay.dart | Running State | Calculate average progress correctly | Progress 0.2 & 0.8 | Pump | Indicator.value==0.5 |
| W-TPB-014 | task_progress_overlay.dart | Running State | Average three running tasks | 0.2,0.4,1.0 | Pump | Average==0.5333 |
| W-TPB-015 | task_progress_overlay.dart | Running State | Ignore completed tasks while averaging | Running + Completed | Pump | Average uses running only |
| W-TPB-016 | task_progress_overlay.dart | Running State | Ignore error tasks while averaging | Running + Error | Pump | Average uses running only |
| W-TPB-017 | task_progress_overlay.dart | Running State | Display progress of 1.0 correctly | Progress=1 | Pump | Indicator.value==1 |
| W-TPB-018 | task_progress_overlay.dart | Running State | Render indicator strokeWidth=10 | Running task | Pump | strokeWidth==10 |
| W-TPB-019 | task_progress_overlay.dart | Running State | Indicator foreground color is white | Running task | Pump | color==Colors.white |
| W-TPB-020 | task_progress_overlay.dart | Running State | Indicator background opacity applied | Running task | Pump | Background color correct |

### Error Tasks

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TPB-021 | task_progress_overlay.dart | Error State | Show error icon when error task exists | One error task | Pump | Error icon visible |
| W-TPB-022 | task_progress_overlay.dart | Error State | Background color uses AppColors.error | Error task | Pump | Decoration color correct |
| W-TPB-023 | task_progress_overlay.dart | Error State | Hide progress indicator | Error task | Pump | Progress absent |
| W-TPB-024 | task_progress_overlay.dart | Error State | Hide success icon | Error task | Pump | Success icon absent |
| W-TPB-025 | task_progress_overlay.dart | Error State | Display shadow for error state | Error task | Pump | BoxShadow exists |

### Success Tasks

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TPB-026 | task_progress_overlay.dart | Success State | Show success icon when all tasks completed | Completed tasks | Pump | Check icon visible |
| W-TPB-027 | task_progress_overlay.dart | Success State | Background uses success green | Completed tasks | Pump | Decoration color==0xFF1B5E20 |
| W-TPB-028 | task_progress_overlay.dart | Success State | Hide progress indicator | Completed tasks | Pump | Indicator absent |
| W-TPB-029 | task_progress_overlay.dart | Success State | Hide error icon | Completed tasks | Pump | Error icon absent |
| W-TPB-030 | task_progress_overlay.dart | Success State | Display shadow | Completed tasks | Pump | Shadow rendered |

### Priority Logic

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TPB-031 | task_progress_overlay.dart | Priority | Running takes precedence over Error | Running + Error | Pump | Progress indicator displayed |
| W-TPB-032 | task_progress_overlay.dart | Priority | Running takes precedence over Completed | Running + Completed | Pump | Progress indicator displayed |
| W-TPB-033 | task_progress_overlay.dart | Priority | Error takes precedence over Completed | Error + Completed | Pump | Error icon displayed |
| W-TPB-034 | task_progress_overlay.dart | Priority | Multiple running and error tasks | Mixed | Pump | Running state shown |
| W-TPB-035 | task_progress_overlay.dart | Priority | Multiple completed tasks | All completed | Pump | Success state shown |

### Provider Updates

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TPB-036 | task_progress_overlay.dart | Riverpod | Rebuild when provider changes | Override provider | Update provider | Widget rebuilds |
| W-TPB-037 | task_progress_overlay.dart | Riverpod | Empty → Running transition | Provider update | Pump | Progress indicator appears |
| W-TPB-038 | task_progress_overlay.dart | Riverpod | Running → Completed transition | Update provider | Pump | Success icon appears |
| W-TPB-039 | task_progress_overlay.dart | Riverpod | Running → Error transition | Update provider | Pump | Error icon appears |
| W-TPB-040 | task_progress_overlay.dart | Riverpod | Error → Completed transition | Update provider | Pump | Success icon replaces error |
| W-TPB-041 | task_progress_overlay.dart | Riverpod | Completed → Empty transition | Update provider | Pump | Placeholder rendered |

### UI Validation

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TPB-042 | task_progress_overlay.dart | IconButton | Tooltip displays "Background Tasks" | Pump | Hover | Tooltip visible |
| W-TPB-043 | task_progress_overlay.dart | IconButton | Icon container width is 20 | Pump | Inspect | Width==20 |
| W-TPB-044 | task_progress_overlay.dart | IconButton | Icon container height is 20 | Pump | Inspect | Height==20 |
| W-TPB-045 | task_progress_overlay.dart | IconButton | Container uses circular decoration | Pump | Inspect | Shape==circle |
| W-TPB-046 | task_progress_overlay.dart | IconButton | Center widget wraps content | Pump | Inspect | Center exists |
| W-TPB-047 | task_progress_overlay.dart | IconButton | IconButton remains enabled when tasks exist | Completed task | Pump | onPressed != null |

### Boundary Conditions

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TPB-048 | task_progress_overlay.dart | Boundary | One hundred completed tasks | 100 completed | Pump | Success state |
| W-TPB-049 | task_progress_overlay.dart | Boundary | One hundred running tasks | 100 running | Pump | Average calculated |
| W-TPB-050 | task_progress_overlay.dart | Boundary | Running progress all zero | All progress=0 | Pump | Indeterminate indicator |
| W-TPB-051 | task_progress_overlay.dart | Boundary | Running progress all one | All progress=1 | Pump | Progress==1 |
| W-TPB-052 | task_progress_overlay.dart | Boundary | Mixed large task list | Running+Completed+Error | Pump | Running state chosen |
| W-TPB-053 | task_progress_overlay.dart | Boundary | Single completed task | One completed | Pump | Success state |
| W-TPB-054 | task_progress_overlay.dart | Boundary | Single running task | One running | Pump | Progress state |
| W-TPB-055 | task_progress_overlay.dart | Boundary | Single error task | One error | Pump | Error state |

### Golden Tests

| Test ID | File(s) Under Test | Target Widget / State | Scenario | Setup | Action | Assertions |
|---------|--------------------|-----------------------|----------|-------|--------|------------|
| W-TPB-056 | task_progress_overlay.dart | Golden | Empty placeholder | Empty provider | Capture | Matches golden |
| W-TPB-057 | task_progress_overlay.dart | Golden | Running state | Running task | Capture | Matches golden |
| W-TPB-058 | task_progress_overlay.dart | Golden | Error state | Error task | Capture | Matches golden |
| W-TPB-059 | task_progress_overlay.dart | Golden | Success state | Completed task | Capture | Matches golden |
| W-TPB-060 | task_progress_overlay.dart | Golden | Mixed running state | Mixed tasks | Capture | Matches golden |

---

## Coverage Notes

### Expected Coverage

**100% widget coverage** is realistically achievable for this file.

### Critical Branches

- ✅ `tasks.isEmpty`
- ✅ `runningTasks.isNotEmpty`
- ✅ `errorTasks.isNotEmpty`
- ✅ Success state (all remaining cases)
- ✅ Progress value > 0
- ✅ Progress value == 0 (indeterminate)
- ✅ Average progress calculation
- ✅ Running priority over Error
- ✅ Error priority over Success
- ✅ Empty placeholder branch
- ✅ Riverpod rebuilds
- ✅ Tooltip rendering
- ✅ Layout constants
- ✅ Decoration branches
- ✅ Shadow branches
- ✅ Golden rendering

### High-Priority Coverage Tests

If your objective is to maximize coverage with the fewest tests, prioritize:

1. **W-TPB-002** (Empty placeholder branch)
2. **W-TPB-011** (Determinate progress)
3. **W-TPB-012** (Indeterminate progress)
4. **W-TPB-013** (Average progress calculation)
5. **W-TPB-021** (Error branch)
6. **W-TPB-026** (Success branch)
7. **W-TPB-031** (Running precedence)
8. **W-TPB-033** (Error precedence)
9. **W-TPB-037 → W-TPB-041** (Provider rebuild transitions)

These tests cover nearly every conditional branch in `build()` and provide the highest return on coverage for this widget. :contentReference[oaicite:0]{index=0}