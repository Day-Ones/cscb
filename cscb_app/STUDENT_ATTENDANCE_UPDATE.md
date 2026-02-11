# Student Attendance System Update

## Overview
The attendance system has been enhanced to capture detailed student information from QR codes and provide advanced sorting and grouping capabilities.

## QR Code Format

### Required Format
The QR code should contain JSON data with the following structure:

```json
{
  "studentNumber": "2023-00495-TG-0",
  "fullName": "Daniel Victorioso",
  "program": "Diploma in Information Technology",
  "yearLevel": "3rd Year",
  "registrationDate": "2026-02-10T20:48:18.245Z",
  "id": "CSCB-2023-00495-TG-0-1770756498245"
}
```

### Required Fields
1. **studentNumber**: Unique identifier (e.g., "2023-00495-TG-0")
2. **fullName**: Student's full name (e.g., "Daniel Victorioso")
3. **program**: Full program name:
   - "Bachelor of Science in Information Technology"
   - "Diploma in Information Technology"
4. **yearLevel**: Year with ordinal suffix:
   - "1st Year", "2nd Year", "3rd Year", "4th Year"

### Optional Fields
- **registrationDate**: ISO 8601 date string
- **id**: Unique QR code identifier

### Storage Format
The system automatically converts the JSON data to abbreviated format for storage:
- "Bachelor of Science in Information Technology" + "3rd Year" → "BSIT 3-1"
- "Diploma in Information Technology" + "2nd Year" → "DIT 2-1"
- Full name "Daniel Victorioso" → First: "Daniel", Last: "Victorioso"
- Format: `{PROGRAM_ABBREV} {YEAR}-1`

### Backward Compatibility
The system also supports the old pipe-separated format for backward compatibility:
```
studentNo|lastName|firstName|program|yearLevel
```

## Features Implemented

### 1. Enhanced Data Capture
- **Student Information**: Full name, student number, program, year level
- **Automatic Timestamp**: Records exact check-in time
- **Duplicate Prevention**: Prevents same student from checking in twice
- **Validation**: Ensures QR code format is correct

### 2. Sorting Options

#### Program & Year Level (Default)
- Groups students by program and year level
- Sorts alphabetically within each group
- Shows group headers with student counts
- Example grouping:
  - BSIT - Year 1
  - BSIT - Year 2
  - DIT - Year 1
  - etc.

#### Check-in Time
- Sorts by most recent check-ins first
- Shows exact time of attendance
- No grouping, flat list

#### Alphabetical
- Sorts by last name, then first name
- Simple A-Z ordering
- No grouping, flat list

### 3. Enhanced Display

#### Attendance Cards Show:
- Student number
- Full name (Last, First format)
- Program and year level
- Check-in time
- Status badge

#### Success Dialog Shows:
- Student's full name
- Student number
- Program and year level
- Check-in time

### 4. Export Enhancements

#### PDF Export Includes:
- Event name and date
- Total attendees
- Table with:
  - Student number
  - Full name
  - Program
  - Year level
  - Check-in time

#### CSV Export Includes:
- All student details in separate columns
- Easy to import into Excel
- Sortable and filterable

## Database Changes

### Schema Version: 6

### Attendance Table Updated:
```dart
class Attendance extends Table with SyncableTable {
  TextColumn get eventId => text().references(Events, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get studentNumber => text();
  TextColumn get lastName => text();
  TextColumn get firstName => text();
  TextColumn get program => text();
  IntColumn get yearLevel => integer();
  DateTimeColumn get timestamp => dateTime();
  TextColumn get status => text().withDefault(const Constant('present'))();
  @override
  Set<Column> get primaryKey => {id};
}
```

## How to Use

### For Event Organizers:

1. **Create Event**
   - Open app → Tap "Create Event"
   - Enter event name → Tap "Create"

2. **Scan Attendance**
   - Open event → Tap "Scan QR Code"
   - Point camera at student's QR code
   - View student details in success dialog
   - Choose "Scan Next" or "Done"

3. **View Attendance List**
   - Open event → Tap "View Attendance List"
   - See all students grouped by program/year
   - Tap sort icon to change sorting
   - Pull down to refresh

4. **Export Data**
   - From attendance list → Tap download icon
   - Choose PDF or CSV
   - Share via email, drive, etc.

### For Testing:

1. **Generate Test QR Codes**
   - From events page → Tap QR icon (top-right)
   - Fill in student information:
     - Student Number: 2023-00495-TG-0
     - Last Name: Victorioso
     - First Name: Daniel
     - Program: Select from dropdown
       - "Bachelor of Science in Information Technology"
       - "Diploma in Information Technology"
     - Year Level: Select from dropdown
       - "1st Year", "2nd Year", "3rd Year", or "4th Year"
   - Tap "Generate QR Data"
   - Copy the generated text (format: `studentNo|lastName|firstName|fullProgram|yearLevel`)
   - Use online QR generator (qr-code-generator.com)
   - Paste the text and generate QR code
   - Scan in the app
   - System will convert to storage format (e.g., "BSIT 1-1")

## UI Improvements

### Attendance List Page:
- **Sort Button**: Top-right, next to download
- **Group Headers**: Blue-purple gradient with count
- **Student Cards**: Show all details at a glance
- **Pull to Refresh**: Update list anytime

### QR Scanner Success Dialog:
- **Student Info Box**: Gray background with all details
- **Formatted Display**: Clean, easy to read
- **Action Buttons**: Done or Scan Next

### QR Generator Page:
- **Dropdown Fields**: Program and Year Level use dropdowns for consistency
- **Program Options**: 
  - Bachelor of Science in Information Technology
  - Diploma in Information Technology
- **Year Level Options**: 1st Year, 2nd Year, 3rd Year, 4th Year
- **Format Helper**: Shows expected format
- **Copy Function**: Easy to copy generated data
- **Automatic Conversion**: Full names converted to abbreviations on scan

## Technical Details

### New Files:
- `lib/core/models/student_attendance.dart` - Student attendance model with sorting/grouping

### Modified Files:
- `lib/data/local/db/app_database.dart` - Enhanced Attendance table
- `lib/data/local/repositories/event_repository.dart` - New methods for student attendance
- `lib/screens/qr_scanner_page.dart` - Enhanced success dialog
- `lib/screens/attendance_list_page.dart` - Sorting, grouping, enhanced display
- `lib/screens/qr_generator_page.dart` - Multiple input fields

### Key Methods:
```dart
// Record student attendance from QR code
Future<Result<StudentAttendance>> recordStudentAttendance({
  required String eventId,
  required String qrData,
});

// Get attendance list with student details
Future<List<StudentAttendance>> getStudentAttendanceList(String eventId);

// Sorting extensions
List<StudentAttendance> sortByProgramYearLevel();
List<StudentAttendance> sortByCheckInTime();
List<StudentAttendance> sortAlphabetically();

// Grouping
Map<String, List<StudentAttendance>> groupByProgramYearLevel();
```

## Migration Notes

- **Database Version**: Upgraded from 5 to 6
- **Automatic Migration**: Attendance table recreated with new fields
- **Data Loss**: Previous attendance records will be cleared (migration drops table)
- **First Run**: May take a moment to migrate database

## Best Practices

1. **QR Code Generation**:
   - Use consistent format
   - Verify data before generating
   - Test scan before event

2. **During Events**:
   - Keep device charged
   - Ensure good lighting
   - Have backup QR codes ready

3. **After Events**:
   - Export data immediately
   - Backup to cloud storage
   - Review for duplicates

4. **Data Management**:
   - Export regularly
   - Keep organized by event
   - Archive old events

## Troubleshooting

### QR Code Not Scanning:
- Check format: JSON object with required fields
- Ensure valid JSON syntax (proper quotes, braces, commas)
- Required fields: studentNumber, fullName, program, yearLevel
- Program must be full name: "Bachelor of Science in Information Technology" or "Diploma in Information Technology"
- Year level must include ordinal: "1st Year", "2nd Year", etc.
- Example valid JSON:
  ```json
  {"studentNumber":"2023-00495-TG-0","fullName":"Daniel Victorioso","program":"Diploma in Information Technology","yearLevel":"3rd Year"}
  ```

### Wrong Student Information:
- QR code format incorrect
- Check for typos in JSON data
- Verify program name matches exactly
- Ensure fullName is in "FirstName LastName" format

### Name Parsing Issues:
- Full name should be "FirstName LastName" format
- System splits on first space: "Daniel Victorioso" → First: "Daniel", Last: "Victorioso"
- Multi-word last names: "John Doe Smith" → First: "John", Last: "Doe Smith"

### Duplicate Check-in Error:
- Student already checked in
- Check attendance list to verify
- Cannot check in twice (by design)

### Sorting Not Working:
- Pull down to refresh list
- Try different sort option
- Check if data loaded correctly

### Program Not Converting:
- Ensure QR code uses full program name in JSON
- System converts "Bachelor of Science in Information Technology" → "BSIT"
- System converts "Diploma in Information Technology" → "DIT"
- If program doesn't match, it will be stored as-is

## Future Enhancements

1. **Real QR Code Generation**: Add `qr_flutter` package
2. **Search Functionality**: Search by name or student number
3. **Filter Options**: Filter by program, year level, time range
4. **Statistics**: Attendance rates, program distribution
5. **Batch Operations**: Bulk check-in, bulk export
6. **User Profiles**: Student profiles with photos
7. **Notifications**: Alert for duplicate attempts
8. **Analytics Dashboard**: Visual charts and graphs

## Support

For issues or questions:
1. Check QR code format
2. Verify all fields are filled
3. Test with QR generator page
4. Review error messages
5. Check documentation

---

**Note**: This system requires physical device with camera. Emulators do not support camera functionality.
