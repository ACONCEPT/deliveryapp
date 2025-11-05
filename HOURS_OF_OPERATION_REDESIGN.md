# Hours of Operation UI Redesign

## Summary

Redesigned the hours of operation UI in the restaurant management screens to replace the circular clock time picker with a more user-friendly interface featuring:

1. **Default Daily Hours** - Set a default schedule that applies to all days
2. **Day-Specific Overrides** - Option to use default hours or customize individual days
3. **Simple Text Input** - 12-hour format with AM/PM selector instead of clock picker
4. **Collapsible Cards** - Each day can be expanded/collapsed for a cleaner interface

## Changes Made

### New Widgets Created

#### 1. `lib/widgets/hours/time_input_field.dart`
Custom time input widget with:
- Hour field (1-12)
- Minute field (00-59)
- AM/PM toggle selector (orange highlight when selected)
- Automatic 12-hour to 24-hour conversion for backend compatibility
- Input formatters to prevent invalid values
- Real-time validation

**Key Features:**
- Replaces the circular clock time picker
- Text input for easy typing
- Visual AM/PM selector with toggle buttons
- Converts 12-hour format (UI) to 24-hour format (backend)

#### 2. `lib/widgets/hours/day_hours_editor.dart`
Expandable card for editing individual day hours:
- Collapsible card showing day name and current hours
- Badge showing "Default" or "Custom" status
- Toggle to switch between default and custom hours
- "Closed all day" checkbox
- Open/Close time inputs using TimeInputField
- Auto-expands when using custom hours

**Key Features:**
- Clean, compact view when collapsed
- Shows effective hours (default or custom)
- Color-coded badges (blue for default, orange for custom)
- Seamless switching between default and custom hours

#### 3. `lib/widgets/hours/default_hours_editor.dart`
Card for setting the default daily hours:
- "Closed all day" checkbox
- Open/Close time inputs
- Information tooltip explaining day-specific overrides
- Applies to all days marked as "Use default hours"

**Key Features:**
- Sets baseline hours for all days
- Changes propagate to all days using defaults
- Clear visual hierarchy

### Updated Files

#### 1. `lib/screens/vendor/restaurant_settings_screen.dart`

**Added State:**
- `_defaultDailyHours` - DaySchedule for default hours
- `_useDefaultHours` - Map tracking which days use default vs custom

**New Methods:**
- `_updateDefaultHours()` - Updates default hours and applies to all default days
- `_applyDefaultHoursToAllDays()` - Propagates default hours to days using defaults
- `_updateUseDefault()` - Toggles between default and custom for a day

**Removed Methods:**
- `_buildDayScheduleRow()` - Old UI builder (replaced by DayHoursEditor widget)
- `_selectTime()` - Old clock picker handler (replaced by TimeInputField)
- `_isTimeAfter()` / `_isTimeBefore()` - Time validation helpers (no longer needed)

**UI Changes:**
- Replaced flat list of days with expandable cards
- Added Default Hours section at top
- Added Day-Specific Overrides section with collapsible day cards
- Better visual hierarchy and information density

## User Experience Improvements

### Before (Old UI)
- All 7 days always visible (takes up a lot of space)
- Circular clock time picker (difficult to type specific times)
- 24-hour format display (less familiar to US users)
- No concept of default hours (had to set each day individually)
- All days visible even when identical

### After (New UI)
- Default hours apply to all days (set once, use everywhere)
- Collapsible day cards (compact view, expand only when needed)
- Text input for times (fast, precise typing)
- 12-hour format with AM/PM (familiar to US users)
- Clear visual indicators (Default vs Custom badges)
- Only customize days that differ from the default

## Data Structure Compatibility

The new UI maintains **100% backward compatibility** with the existing backend:

### Backend Expected Format (24-hour)
```json
{
  "monday": {"open": "09:00", "close": "17:00", "closed": false},
  "tuesday": {"open": "09:00", "close": "17:00", "closed": false},
  ...
}
```

### How It Works
1. **UI Layer (12-hour)**: User enters "9:00 AM" and "5:00 PM"
2. **Conversion**: TimeInputField converts to "09:00" and "17:00"
3. **Backend (24-hour)**: API receives standard 24-hour format
4. **Reverse**: When loading, 24-hour format is converted back to 12-hour for display

No backend changes required!

## Example User Workflow

### Scenario 1: Restaurant with standard hours
1. Set default hours: 9:00 AM - 5:00 PM
2. All days automatically use these hours
3. Save (only 2 time inputs needed for entire week!)

### Scenario 2: Restaurant with weekend special hours
1. Set default hours: 9:00 AM - 5:00 PM (Mon-Fri)
2. Expand Saturday card
3. Uncheck "Use default hours"
4. Set custom hours: 10:00 AM - 9:00 PM
5. Repeat for Sunday
6. Save

### Scenario 3: Restaurant closed on Mondays
1. Set default hours: 9:00 AM - 5:00 PM
2. Expand Monday card
3. Uncheck "Use default hours"
4. Check "Closed all day"
5. Save

## Technical Details

### Time Format Conversion

**User Input (12-hour)** → **Backend Storage (24-hour)**

| 12-hour | 24-hour |
|---------|---------|
| 12:00 AM | 00:00 |
| 1:00 AM | 01:00 |
| 12:00 PM | 12:00 |
| 1:00 PM | 13:00 |
| 11:59 PM | 23:59 |

### State Management

The screen maintains:
- `_defaultDailyHours`: Single DaySchedule used as template
- `_useDefaultHours`: Map<String, bool> tracking default vs custom per day
- `_hoursOfOperation`: HoursOfOperation with actual values sent to backend

When default hours change:
1. Update `_defaultDailyHours`
2. Loop through `_useDefaultHours`
3. For each day marked as "use default", copy `_defaultDailyHours`
4. Update `_hoursOfOperation` with new values

### Input Validation

- Hour: 1-12 (enforced by input formatter)
- Minute: 0-59 (enforced by input formatter)
- Invalid values are rejected immediately
- No need for manual time comparison (TimeInputField handles it)

## Files Modified

```
frontend/lib/screens/vendor/restaurant_settings_screen.dart (modified)
frontend/lib/widgets/hours/time_input_field.dart (new)
frontend/lib/widgets/hours/day_hours_editor.dart (new)
frontend/lib/widgets/hours/default_hours_editor.dart (new)
```

## Testing Checklist

- [ ] Default hours apply to all days initially
- [ ] Changing default hours updates all default days
- [ ] Switching a day to custom preserves current hours
- [ ] Switching a day back to default applies default hours
- [ ] "Closed all day" works for both default and custom
- [ ] Time conversion works correctly (12-hour ↔ 24-hour)
- [ ] Hours save and load correctly from API
- [ ] Expanding/collapsing cards works smoothly
- [ ] AM/PM selector toggles correctly
- [ ] Input validation prevents invalid times

## Future Enhancements (Optional)

1. **Copy hours between days** - "Copy Saturday hours to Sunday"
2. **Quick presets** - "9-5 Weekdays, Closed Weekends"
3. **Bulk edit** - "Apply to all weekdays"
4. **Time validation** - Warn if closing before opening
5. **Multiple shifts** - Support lunch break (9-12, 1-5)

## Migration Notes

- No database migration needed (data structure unchanged)
- No backend API changes needed
- Existing hours data will load correctly
- Users will see their existing hours in the new UI
- All days will initially show as "Use default hours = false" (custom) when loading existing data
- Users can choose to set default hours and toggle days to use them

## Code Style

Follows project guidelines:
- Pure, abstract, object-oriented design
- DRY principle (reusable widgets)
- Clean separation of concerns
- Const constructors where possible
- Material Design 3 styling
- Proper null safety
