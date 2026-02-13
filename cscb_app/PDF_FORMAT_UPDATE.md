# PDF Format Update - Formal Layout

## Summary
Redesigned the PDF attendance report to have a more formal, professional layout with better organization and visual hierarchy.

## New PDF Layout

### Header Section
```
                    ATTENDANCE REPORT
                    (centered, bold, large)

Event: [Event Name]                    Date: [Event Date]
(left aligned)                         (right aligned)

Year & Section: [Section or "All Year Levels"]
Total Attendees: [Count]

─────────────────────────────────────────────────────
```

### Table Section
Professional table with:
- Gray header background
- Border around all cells
- Proper padding
- Columns: #, Student No., Name, Program, Year, Check-in Time

## Changes Made

### File: `lib/screens/attendance_list_page.dart`

#### 1. Title Formatting
- Changed from "Attendance Report" to "ATTENDANCE REPORT"
- Centered the title
- Added letter spacing (1.5) for formal appearance
- Reduced font size from 24 to 20 for better proportion

#### 2. Event Info Layout
- **Event Name & Date**: Now on the same line
  - Event name on the left
  - Date on the right
  - Both use Row with spaceBetween alignment
- **Year & Section**: Shows filtered section or "All Year Levels"
  - Changed from "Filter: DIT 3-1" to "Year & Section: DIT 3-1"
  - Changed from "Filter: All Sections" to "Year & Section: All Year Levels"
- **Total Attendees**: Bold text for emphasis

#### 3. Visual Improvements
- Added 40pt margins on all sides (was default)
- Added divider line between header and table
- Increased spacing between sections
- Better visual hierarchy

#### 4. Table Styling
- **Header**: Gray background (PdfColors.grey300)
- **Borders**: All cells have borders (0.5pt, grey)
- **Padding**: Consistent padding (8pt header, 6pt cells)
- **Font Sizes**: Slightly smaller for better fit (10pt header, 9pt cells)

## Layout Comparison

### Before
```
Attendance Report
Event: SPADE
Date: Feb 13, 2026
Filter: DIT 3-1
Total Attendees: 1

[Table with no borders or background]
```

### After
```
                ATTENDANCE REPORT

Event: SPADE                           Date: Feb 13, 2026
Year & Section: DIT 3-1
Total Attendees: 1

─────────────────────────────────────────────────────

[Professional table with borders and gray header]
```

## Key Features

1. **Centered Title**: "ATTENDANCE REPORT" is prominently centered
2. **Aligned Info**: Event name and date are on the same line, properly aligned
3. **Clear Hierarchy**: Information flows logically from top to bottom
4. **Professional Table**: Gray header, borders, proper spacing
5. **Better Margins**: 40pt margins create white space
6. **Formal Language**: "Year & Section" instead of "Filter"
7. **All Year Levels**: Shows "All Year Levels" when no filter is applied

## Text Changes

| Old Text | New Text |
|----------|----------|
| "Filter: All Sections" | "Year & Section: All Year Levels" |
| "Filter: DIT 3-1" | "Year & Section: DIT 3-1" |
| "Attendance Report" | "ATTENDANCE REPORT" |

## Benefits

1. **More Professional**: Formal layout suitable for official documents
2. **Better Readability**: Clear visual hierarchy and spacing
3. **Cleaner Design**: Centered title, aligned information
4. **Formal Language**: "Year & Section" is more appropriate than "Filter"
5. **Visual Appeal**: Gray header and borders make table easier to read

## Testing Checklist
- [ ] Export PDF with "All Year Levels" - verify text shows correctly
- [ ] Export PDF with specific section (e.g., "DIT 3-1") - verify text shows correctly
- [ ] Verify title is centered
- [ ] Verify event name is on left, date is on right
- [ ] Verify table has gray header
- [ ] Verify table has borders
- [ ] Verify margins look good on A4 paper
- [ ] Verify all text is readable

## Related Files
- `lib/screens/attendance_list_page.dart` - PDF export implementation
