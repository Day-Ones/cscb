# Export Filter Feature

## Overview
Added section filtering capability to PDF and CSV exports, allowing users to export attendance records for specific sections (e.g., "BSIT 3-1", "DIT 1-1") or all sections.

## Implementation

### Changes Made
Updated `lib/screens/attendance_list_page.dart`:

1. **Filter State**: Added `_exportFilterSection` to track selected filter
2. **Helper Methods**:
   - `_getAvailableSections()`: Extracts unique sections from attendance list
   - `_getFilteredList()`: Returns filtered records based on selected section
   - `_showFilterDialog()`: Shows modal bottom sheet with filter options

3. **Export Methods Updated**:
   - `_exportToPDF()`: Now shows filter dialog first, uses filtered list, adds filter info to report
   - `_exportToExcel()`: Now shows filter dialog first, uses filtered list, adds filter info to CSV

### User Experience

When exporting (PDF or CSV):
1. User clicks export button
2. Filter dialog appears with:
   - "All Sections" option (shows total count)
   - Individual section options (e.g., "BSIT 3-1", "DIT 1-1") with counts
   - Visual indicators for selected option
3. User selects filter
4. Export proceeds with filtered data
5. Filter information included in:
   - PDF report header
   - CSV report header
   - Filename suffix (e.g., `_BSIT_3-1` or `_all`)
   - Success message

### Filter Dialog Features
- Clean, modern UI with icons and colors
- Shows student count for each section
- Visual feedback for selected option
- Scrollable list for many sections
- Easy to understand labels

### File Naming
- All sections: `attendance_EventName_all.pdf`
- Specific section: `attendance_EventName_BSIT_3-1.pdf`

## Testing Checklist
- [ ] Filter dialog shows all unique sections
- [ ] "All Sections" exports complete list
- [ ] Individual section filters work correctly
- [ ] PDF includes filter information in header
- [ ] CSV includes filter information in header
- [ ] Filenames include filter suffix
- [ ] Success messages show filter information
- [ ] Student counts are accurate in dialog
- [ ] Works with empty attendance list
- [ ] Works with single section
- [ ] Works with multiple sections

## Related Files
- `lib/screens/attendance_list_page.dart` - Main implementation
- `lib/core/models/student_attendance.dart` - Data model with program field
