# Event Date Picker Feature

## Summary
Added date and time pickers to the simple event creation dialog, allowing users to create events for future dates.

## Changes Made

### File: `lib/screens/events_home_page.dart`

#### 1. Updated `_showCreateEventDialog()` Method
- Changed return type from `bool` to `Map<String, dynamic>?`
- Now returns both event name and selected date/time
- Calls new `_CreateEventDialog` widget

#### 2. Updated `_createEvent()` Method
- Added `DateTime eventDate` parameter
- Changed from `eventDate: Value(DateTime.now())` to `eventDate: Value(eventDate)`
- Now uses the user-selected date instead of current date

#### 3. Added New `_CreateEventDialog` Widget
A StatefulWidget dialog with:
- **Event Name Field**: Text input for event name
- **Date Picker**: Calendar picker for selecting event date
  - Only allows current date and future dates
  - Allows dates up to 5 years in the future
  - Displays selected date in format: "Jan 15, 2025"
- **Time Picker**: Clock picker for selecting event time
  - 12-hour format with AM/PM
  - Displays selected time in format: "2:30 PM"
- **Validation**: Ensures all fields are filled before creating event
- **Clean UI**: Matches existing app design with gradient icons

## User Experience

### Before
1. Click "Create Event" button
2. Enter event name only
3. Event created with current date/time

### After
1. Click "Create Event" button
2. Enter event name
3. Select event date (calendar picker)
4. Select event time (clock picker)
5. Click "Create" button
6. Event created with selected date/time

### Validation
- Shows error if event name is empty
- Shows error if date is not selected
- Shows error if time is not selected
- All errors shown as red snackbars

## Technical Details

### Date/Time Combination
```dart
final eventDateTime = DateTime(
  _selectedDate!.year,
  _selectedDate!.month,
  _selectedDate!.day,
  _selectedTime!.hour,
  _selectedTime!.minute,
);
```

### Date Restrictions
- Minimum date: Current date (`firstDate: now`)
- Maximum date: 5 years in future (`lastDate: DateTime(now.year + 5)`)

### Format Functions
- `_formatDate()`: Formats date as "Jan 15, 2025"
- `_formatTime()`: Formats time as "2:30 PM"

## Impact on Reports

Now that events can be created with future dates:
- **Events List**: Shows the scheduled event date
- **Attendance Reports (PDF)**: Shows the scheduled event date
- **Attendance Reports (CSV)**: Shows the scheduled event date
- **Event Details**: Shows the scheduled event date

All reports correctly use `event.eventDate` (not `event.createdAt`), so they will display the user-selected date.

## Testing Checklist
- [ ] Create event for today - should work
- [ ] Create event for tomorrow - should work
- [ ] Create event for next week - should work
- [ ] Create event for next year - should work
- [ ] Try to create event without name - should show error
- [ ] Try to create event without date - should show error
- [ ] Try to create event without time - should show error
- [ ] Verify event shows correct date in events list
- [ ] Verify attendance report shows correct date
- [ ] Verify event syncs to Supabase with correct date

## Related Files
- `lib/screens/events_home_page.dart` - Main implementation
- `lib/screens/attendance_list_page.dart` - Uses event.eventDate for reports
- `lib/data/local/db/app_database.dart` - Database schema with eventDate field
