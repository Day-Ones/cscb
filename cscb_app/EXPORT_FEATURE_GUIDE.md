# Attendance Export Feature Guide

## Overview
The app now includes comprehensive attendance tracking with list view and export functionality. You can view all attendees and export reports in PDF or CSV format.

## Features

### 1. Attendance List View
- **Access**: Event Attendance Page → "View Attendance List" button
- **Display**:
  - Numbered list of all attendees
  - User IDs
  - Check-in timestamps
  - Status badges
  - Modern card-based design
- **Interactions**:
  - Pull to refresh
  - Tap download icon to export
  - Back button to return

### 2. PDF Export
- **Format**: Professional formatted document
- **Contents**:
  - Event name and date
  - Total attendees count
  - Formatted table with:
    - Row numbers
    - User IDs
    - Check-in times
    - Status
- **File Name**: `attendance_[EventName].pdf`
- **Sharing**: Via system share sheet

### 3. CSV Export
- **Format**: Excel-compatible spreadsheet
- **Contents**:
  - Event metadata (name, date, count)
  - Attendance table with all records
  - Headers for easy import
- **File Name**: `attendance_[EventName].csv`
- **Sharing**: Via system share sheet
- **Compatible With**:
  - Microsoft Excel
  - Google Sheets
  - Numbers (Mac)
  - Any spreadsheet software

## How to Use

### Viewing Attendance List

1. **Navigate to Event**:
   - Open the app
   - Tap on an event card
   - You'll see the Event Attendance page

2. **Open Attendance List**:
   - Tap the orange "View Attendance List" button
   - The list loads automatically

3. **Review Attendees**:
   - Scroll through the list
   - See user IDs and check-in times
   - Pull down to refresh if needed

### Exporting Attendance

1. **Open Export Menu**:
   - From the attendance list page
   - Tap the download icon (top-right)
   - A bottom sheet appears with options

2. **Choose Format**:
   - **PDF**: For printing or formal reports
     - Professional layout
     - Ready to print
     - Good for presentations
   - **CSV**: For data analysis
     - Import into Excel/Sheets
     - Perform calculations
     - Create charts

3. **Share the File**:
   - System share sheet opens
   - Choose destination:
     - Email
     - Google Drive
     - Dropbox
     - WhatsApp
     - Any other app

## Export File Details

### PDF Structure
```
Attendance Report
Event: [Event Name]
Date: [Event Date]
Total Attendees: [Count]

┌────┬──────────┬─────────────────┬─────────┐
│ #  │ User ID  │ Check-in Time   │ Status  │
├────┼──────────┼─────────────────┼─────────┤
│ 1  │ user123  │ Feb 14, 2026... │ present │
│ 2  │ user456  │ Feb 14, 2026... │ present │
└────┴──────────┴─────────────────┴─────────┘
```

### CSV Structure
```csv
Event,[Event Name]
Date,[Event Date]
Total Attendees,[Count]

#,User ID,Check-in Time,Status
1,user123,Feb 14 2026 at 10:30 AM,present
2,user456,Feb 14 2026 at 10:31 AM,present
```

## Use Cases

### 1. Event Reports
- Export PDF after event
- Email to organizers
- Print for records
- Include in event documentation

### 2. Data Analysis
- Export CSV
- Import into Excel/Sheets
- Create attendance charts
- Calculate statistics
- Track trends over time

### 3. Record Keeping
- Export after each event
- Store in cloud (Drive, Dropbox)
- Maintain historical records
- Compliance documentation

### 4. Sharing with Stakeholders
- Export PDF for presentations
- Email to administrators
- Share with team members
- Include in reports

## Technical Details

### Packages Used
- **pdf: ^3.10.0**: PDF generation
- **csv: ^6.0.0**: CSV formatting
- **share_plus: ^7.2.0**: File sharing
- **path_provider: ^2.1.0**: Temporary file storage

### File Storage
- Files created in temporary directory
- Automatically cleaned up by system
- No permanent storage on device
- Shared via system share sheet

### Data Format
- **Timestamps**: Formatted as "MMM DD, YYYY at HH:MM AM/PM"
- **User IDs**: Plain text from QR codes
- **Status**: Currently always "present"
- **Numbering**: Sequential from 1

## Best Practices

### For Event Organizers
1. **Export Immediately**: Export right after event while data is fresh
2. **Multiple Formats**: Export both PDF and CSV for different uses
3. **Backup**: Store exports in cloud storage
4. **Share Promptly**: Send reports to stakeholders quickly
5. **Archive**: Keep historical records organized

### For Data Analysis
1. **Use CSV**: Better for spreadsheet analysis
2. **Import to Sheets**: Use Google Sheets for collaboration
3. **Create Charts**: Visualize attendance trends
4. **Compare Events**: Track attendance across multiple events
5. **Calculate Metrics**: Attendance rates, peak times, etc.

### For Record Keeping
1. **Consistent Naming**: Use event names consistently
2. **Date Organization**: Organize by date in folders
3. **Cloud Backup**: Use Drive or Dropbox
4. **Version Control**: Keep original exports
5. **Access Control**: Share with appropriate permissions

## Troubleshooting

### Export Not Working
- ✅ Check storage permissions
- ✅ Ensure sufficient storage space
- ✅ Try again with fewer attendees
- ✅ Restart the app

### Share Sheet Not Appearing
- ✅ Check app permissions
- ✅ Ensure share apps are installed
- ✅ Try exporting again
- ✅ Restart device if needed

### File Not Opening
- ✅ Ensure compatible app installed
- ✅ Try different app (PDF reader, Excel)
- ✅ Re-export the file
- ✅ Check file integrity

### Empty Export
- ✅ Verify attendance records exist
- ✅ Refresh attendance list
- ✅ Check event has attendees
- ✅ Try scanning QR codes again

## Future Enhancements

Potential improvements:
1. **Email Integration**: Direct email sending
2. **Custom Templates**: Customizable report layouts
3. **Scheduled Exports**: Automatic exports at set times
4. **Cloud Sync**: Direct upload to Drive/Dropbox
5. **Batch Export**: Export multiple events at once
6. **Advanced Filtering**: Export filtered subsets
7. **Charts in PDF**: Include attendance charts
8. **Excel Format**: Native .xlsx support

## Security & Privacy

- **Local Processing**: All exports generated locally
- **No Cloud Upload**: Files not automatically uploaded
- **User Control**: User chooses where to share
- **Temporary Storage**: Files cleaned up automatically
- **No Tracking**: No analytics on exports

## Support

For issues or questions:
- Check the main documentation
- Review troubleshooting section
- Test with sample data
- Verify app permissions

---

**Ready to Export!** Start tracking attendance and generating professional reports today.
