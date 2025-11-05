# Hours of Operation - Quick Start Guide

## For Developers

### Running the App
```bash
# Navigate to frontend
cd /Users/josephsadaka/Repos/delivery_app/frontend

# Get dependencies
flutter pub get

# Run the app
flutter run -d chrome

# Login as vendor
# Username: testvendor (or vendor1)
# Password: password123

# Navigate to: Restaurant Settings
```

### File Structure
```
frontend/lib/
├── screens/vendor/
│   └── restaurant_settings_screen.dart   # Main settings screen (updated)
└── widgets/hours/
    ├── time_input_field.dart              # 12-hour time input (NEW)
    ├── day_hours_editor.dart              # Day-specific editor (NEW)
    └── default_hours_editor.dart          # Default hours card (NEW)
```

### Key Components

#### TimeInputField
```dart
TimeInputField(
  label: 'Open',
  initialTime: '09:00',  // 24-hour format
  onTimeChanged: (time) {
    // time is in 24-hour format: "09:00", "17:00", etc.
    print('New time: $time');
  },
)
```

#### DayHoursEditor
```dart
DayHoursEditor(
  dayName: 'Monday',
  daySchedule: currentSchedule,
  defaultSchedule: defaultHours,
  useDefault: true,
  onScheduleChanged: (schedule) {
    // Called when hours change
  },
  onUseDefaultChanged: (useDefault) {
    // Called when "Use default" is toggled
  },
)
```

#### DefaultHoursEditor
```dart
DefaultHoursEditor(
  defaultSchedule: defaultHours,
  onScheduleChanged: (schedule) {
    // Called when default hours change
    // Automatically propagates to all days using defaults
  },
)
```

## For Users

### Setting Up Hours (First Time)

1. **Open Restaurant Settings**
   - Login as vendor
   - Click on your restaurant
   - Click "Settings" button

2. **Set Default Hours**
   - Look for "Default Daily Hours" at the top
   - Uncheck "Closed all day" if checked
   - Type hours:
     - **Open**: Hour field, Minute field, click AM or PM
     - **Close**: Hour field, Minute field, click AM or PM
   - Example: 9:00 AM - 5:00 PM

3. **Review Days**
   - All days will show "9:00 AM - 5:00 PM [Default]"
   - This means they're using your default hours

4. **Click "Save Settings"**
   - Done! Your restaurant now has hours set for the entire week

### Customizing Specific Days

#### Example: Different Weekend Hours

**Goal**: Mon-Fri 9AM-5PM, Sat-Sun 10AM-9PM

1. Set default hours: 9:00 AM - 5:00 PM (Mon-Fri will use these)
2. Click on **Saturday** card to expand
3. Uncheck "Use default daily hours"
4. Set custom hours: 10:00 AM - 9:00 PM
5. Repeat for **Sunday**
6. Click "Save Settings"

Result:
- Mon-Fri: 9:00 AM - 5:00 PM [Default]
- Sat-Sun: 10:00 AM - 9:00 PM [Custom]

#### Example: Closed on Mondays

**Goal**: Closed Mon, Tue-Sun 9AM-5PM

1. Set default hours: 9:00 AM - 5:00 PM
2. Expand **Monday** card
3. Uncheck "Use default daily hours"
4. Check "Closed all day"
5. Click "Save Settings"

Result:
- Monday: Closed [Custom]
- Tue-Sun: 9:00 AM - 5:00 PM [Default]

#### Example: Different Hours Every Day

1. Set default hours: 9:00 AM - 5:00 PM (or leave as is)
2. For each day:
   - Expand the day's card
   - Uncheck "Use default daily hours"
   - Set custom hours or mark as closed
3. Click "Save Settings"

### Tips & Tricks

#### Quick Setup
- **Uniform hours**: Set default once, save. Done!
- **Weekend variation**: Set default for weekdays, customize Sat/Sun
- **One-off closure**: Expand day, uncheck default, check "Closed all day"

#### Editing Hours
- **Change default**: All days marked "Default" will update automatically
- **Switch to custom**: Uncheck "Use default" to set specific hours
- **Switch back to default**: Check "Use default" to revert to default hours

#### Time Input
- **Type directly**: Click field, type numbers
- **No need to delete**: Just start typing, it replaces
- **AM/PM**: Click to toggle (orange = selected)
- **24-hour to 12-hour**:
  - 00:00 = 12:00 AM (midnight)
  - 12:00 = 12:00 PM (noon)
  - 13:00 = 1:00 PM
  - 23:59 = 11:59 PM

#### Visual Cues
- **Blue badge** = Using default hours
- **Orange badge** = Custom hours
- **Italic "Closed"** = Day is closed
- **Arrow down** = Card is collapsed
- **Arrow up** = Card is expanded

### Common Scenarios

#### Scenario 1: Standard Business Hours
**Setup**: Mon-Fri 9-5, Closed weekends
1. Default: 9:00 AM - 5:00 PM
2. Expand Sat, uncheck default, check "Closed all day"
3. Expand Sun, uncheck default, check "Closed all day"
4. Save

#### Scenario 2: Late Night Weekend
**Setup**: Mon-Thu 11-9, Fri-Sat 11-11, Closed Sun
1. Default: 11:00 AM - 9:00 PM (Mon-Thu use this)
2. Expand Fri, uncheck default, set 11:00 AM - 11:00 PM
3. Expand Sat, uncheck default, set 11:00 AM - 11:00 PM
4. Expand Sun, uncheck default, check "Closed all day"
5. Save

#### Scenario 3: Brunch on Weekends
**Setup**: Mon-Fri 5-10 PM, Sat-Sun 10-10 (brunch + dinner)
1. Default: 5:00 PM - 10:00 PM (weekdays)
2. Expand Sat, uncheck default, set 10:00 AM - 10:00 PM
3. Expand Sun, uncheck default, set 10:00 AM - 10:00 PM
4. Save

#### Scenario 4: Changing Default Hours
**Current**: Default is 9-5, all days use it
**Goal**: Change to 10-6
1. Edit default hours: 10:00 AM - 6:00 PM
2. All days marked "Default" automatically update to 10-6
3. Days marked "Custom" remain unchanged
4. Save

### Troubleshooting

#### "I can't change the time inputs"
- Make sure "Use default daily hours" is **unchecked**
- Make sure "Closed all day" is **unchecked**
- If both are unchecked, time inputs should be editable

#### "My changes didn't save"
- Check for error messages
- Make sure you clicked "Save Settings" button
- Verify you have an internet connection
- Check that hours are valid (open before close)

#### "How do I reset a day to default?"
- Expand the day's card
- Check "Use default daily hours"
- The day will automatically use default hours
- Click "Save Settings"

#### "Can I have multiple shifts (lunch break)?"
- Not currently supported
- You can only set one open time and one close time per day
- Feature may be added in the future

#### "What if I want to close early on holidays?"
- Currently, you'll need to manually change the hours for that day
- Set the day to "Custom" and adjust or mark "Closed all day"
- Remember to change back after the holiday

## Testing Checklist

Before deploying to production, test:

- [ ] Set default hours (9:00 AM - 5:00 PM)
- [ ] Verify all days show default hours
- [ ] Change default hours, verify all default days update
- [ ] Set one day to custom hours
- [ ] Set one day to closed
- [ ] Save settings
- [ ] Refresh page, verify hours persist
- [ ] Switch custom day back to default
- [ ] Verify AM/PM toggle works correctly
- [ ] Test with 12:00 AM (midnight)
- [ ] Test with 12:00 PM (noon)
- [ ] Test with late hours (11:00 PM)
- [ ] Expand/collapse all day cards
- [ ] Test on mobile device
- [ ] Test on different screen sizes

## Known Limitations

1. **Single shift only**: Cannot set lunch break hours (e.g., 9-12, 1-5)
2. **No bulk editing**: Must set each custom day individually
3. **No presets**: No "9-5 Weekdays" quick button
4. **No copy**: Cannot copy hours from one day to another
5. **Manual time entry**: No calendar picker for dates

These may be added in future updates based on user feedback.

## Support

If you encounter issues:
1. Check browser console for errors
2. Verify backend is running (http://localhost:8080)
3. Check network tab for failed API calls
4. Review backend logs for server errors
5. File an issue with screenshots and error messages
