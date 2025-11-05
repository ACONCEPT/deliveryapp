# Hours of Operation - Visual UI Guide

## New UI Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ Hours of Operation                                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ 🕐 Default Daily Hours                                      │ │
│ │                                                             │ │
│ │ Set the default hours that apply to all days               │ │
│ │                                                             │ │
│ │ ☐ Closed all day                                           │ │
│ │    Restaurant is closed by default                         │ │
│ │                                                             │ │
│ │ Open                    Close                              │ │
│ │ ┌──┬──┐     ┌────────┐  ┌──┬──┐     ┌────────┐           │ │
│ │ │09│:│00│ ─  │ AM│PM │  │05│:│00│ ─  │ AM│PM │           │ │
│ │ └──┴──┘     └────────┘  └──┴──┘     └────────┘           │ │
│ │                                                             │ │
│ │ ℹ️  You can override specific days below                   │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ Day-Specific Overrides                                         │
│ Customize hours for specific days or use default hours         │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Monday     9:00 AM - 5:00 PM     [Default] 🔽              │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Tuesday    10:00 AM - 9:00 PM    [Custom]  🔽              │ │
│ ├─────────────────────────────────────────────────────────────┤ │
│ │ ☑ Use default daily hours                                  │ │
│ │    9:00 AM - 5:00 PM                                       │ │
│ │                                                             │ │
│ │ ☐ Closed all day                                           │ │
│ │                                                             │ │
│ │ Open                    Close                              │ │
│ │ ┌──┬──┐     ┌────────┐  ┌──┬──┐     ┌────────┐           │ │
│ │ │10│:│00│ ─  │ AM│PM │  │09│:│00│ ─  │ AM│PM │           │ │
│ │ └──┴──┘     └────────┘  └──┴──┘     └────────┘           │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Wednesday  9:00 AM - 5:00 PM     [Default] 🔽              │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ ... (Thursday, Friday, Saturday, Sunday)                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

[Cancel]                          [Save Settings]
```

## Component Breakdown

### 1. Time Input Field

```
Open
┌──┬──┐     ┌────────┐
│09│:│00│ ─  │ AM│PM │
└──┴──┘     └────────┘
 ↑    ↑         ↑
Hour  Min    AM/PM Selector
(1-12) (00-59)  (Toggle)
```

**Features:**
- Type directly into hour/minute fields
- Click AM/PM to toggle
- Automatic validation (prevents 13:00, 60 minutes, etc.)
- Converts to 24-hour format for backend

### 2. Default Hours Card

```
┌───────────────────────────────────────┐
│ 🕐 Default Daily Hours                │
│                                       │
│ Set the default hours that apply to  │
│ all days                              │
│                                       │
│ ☐ Closed all day                     │
│    Restaurant is closed by default   │
│                                       │
│ [Time Input]    [Time Input]         │
│                                       │
│ ℹ️ You can override specific days    │
│    below                              │
└───────────────────────────────────────┘
```

**Purpose:** Set baseline hours that apply to all days

### 3. Day Editor Card (Collapsed)

```
┌───────────────────────────────────────┐
│ Monday  9:00 AM - 5:00 PM  [Default] 🔽│
└───────────────────────────────────────┘
  ↑           ↑                  ↑      ↑
 Day     Current Hours        Badge   Expand
```

**States:**
- **Default Badge** (Blue): Uses default hours
- **Custom Badge** (Orange): Has custom hours

### 4. Day Editor Card (Expanded - Using Default)

```
┌───────────────────────────────────────┐
│ Monday  9:00 AM - 5:00 PM  [Default] 🔼│
├───────────────────────────────────────┤
│ ☑ Use default daily hours            │
│    9:00 AM - 5:00 PM                 │
│                                       │
│ (Custom hours section disabled)      │
└───────────────────────────────────────┘
```

### 5. Day Editor Card (Expanded - Custom Hours)

```
┌───────────────────────────────────────┐
│ Tuesday 10:00 AM - 9:00 PM  [Custom] 🔼│
├───────────────────────────────────────┤
│ ☐ Use default daily hours            │
│    9:00 AM - 5:00 PM                 │
│                                       │
│ ☐ Closed all day                     │
│                                       │
│ Open        Close                    │
│ [10:00 AM]  [09:00 PM]               │
└───────────────────────────────────────┘
```

### 6. Day Editor Card (Closed)

```
┌───────────────────────────────────────┐
│ Sunday     Closed         [Custom] 🔼 │
├───────────────────────────────────────┤
│ ☐ Use default daily hours            │
│    9:00 AM - 5:00 PM                 │
│                                       │
│ ☑ Closed all day                     │
│                                       │
│ (Time inputs hidden)                 │
└───────────────────────────────────────┘
```

## User Interactions

### Setting Default Hours

1. User sees "Default Daily Hours" card at top
2. Unchecks "Closed all day" if needed
3. Sets Open time: Types "9" in hour, "00" in minute, clicks "AM"
4. Sets Close time: Types "5" in hour, "00" in minute, clicks "PM"
5. All days marked "Use default" automatically update to 9:00 AM - 5:00 PM

### Customizing a Specific Day

1. User clicks on "Tuesday" card to expand
2. Card expands showing current settings
3. User unchecks "Use default daily hours"
4. Badge changes from [Default] to [Custom]
5. Time inputs become enabled
6. User sets custom hours: 10:00 AM - 9:00 PM
7. Clicks elsewhere or collapses card
8. Tuesday now shows custom hours

### Marking a Day as Closed

1. User expands "Sunday" card
2. Unchecks "Use default daily hours"
3. Checks "Closed all day"
4. Time inputs disappear
5. Card summary shows "Closed"

### Reverting to Default

1. User expands "Tuesday" card (currently custom)
2. Checks "Use default daily hours"
3. Badge changes from [Custom] to [Default]
4. Time inputs become disabled
5. Hours automatically update to match default (9:00 AM - 5:00 PM)

## Color Scheme

- **Default Badge**: Blue background (`Colors.blue[100]`), dark blue text
- **Custom Badge**: Orange background (`Colors.orange[100]`), dark orange text
- **Active AM/PM**: Deep orange background (`Colors.deepOrange`)
- **Inactive AM/PM**: Transparent with gray border
- **Info Box**: Light blue background with blue border
- **Section Headers**: Deep orange icon, gray text

## Responsive Behavior

- Time inputs use fixed widths (60px for hour/minute)
- Day cards expand vertically when opened
- AM/PM selector uses fixed width (80px)
- Layout adapts to available width
- All cards stack vertically

## Accessibility

- Clear labels for all inputs
- Toggle buttons have proper contrast ratios
- Expandable cards have visual indicators (arrows)
- Status badges are color + text (not just color)
- Helper text explains functionality
- Proper touch targets for mobile

## Animation

- Smooth expansion/collapse of day cards
- Badge color transitions when switching modes
- No jarring layout shifts
- Instant feedback on time input

## Edge Cases Handled

1. **Invalid Times**: Input formatters prevent typing invalid values
2. **Missing Data**: Defaults to 9:00 AM - 9:00 PM if backend returns null
3. **All Days Closed**: Allowed (user can close all days if needed)
4. **Same Hours Every Day**: Efficient (set default once, done!)
5. **Different Hours Every Day**: Supported (uncheck default for each day)

## Mobile Considerations

- Touch-friendly AM/PM toggle buttons
- Larger input fields for easier tapping
- Expandable cards reduce scrolling
- Clear visual hierarchy
- One-handed operation possible
