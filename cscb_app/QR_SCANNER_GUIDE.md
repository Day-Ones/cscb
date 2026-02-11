# QR Scanner Implementation Guide

## Overview
The app now includes a fully functional QR code scanner for event attendance tracking with a modern, gradient-based UI design.

## Features Implemented

### 1. QR Code Scanner
- **Location**: `lib/screens/qr_scanner_page.dart`
- **Package**: `mobile_scanner: ^5.0.0`
- **Features**:
  - Real-time QR code scanning
  - Custom overlay with scanning frame
  - Flashlight toggle
  - Success/error feedback
  - Duplicate attendance prevention

### 2. Attendance List View
- **Location**: `lib/screens/attendance_list_page.dart`
- **Features**:
  - View all attendees for an event
  - Display check-in times
  - Numbered list with user IDs
  - Status badges
  - Pull to refresh
  - Modern card-based design

### 3. Export Functionality
- **Packages**: `pdf: ^3.10.0`, `csv: ^6.0.0`, `share_plus: ^7.2.0`
- **Export Formats**:
  - **PDF**: Formatted document with event details and attendance table
  - **CSV**: Excel-compatible spreadsheet format
- **Features**:
  - Export via share sheet (email, drive, etc.)
  - Includes event name, date, and total count
  - Formatted attendance table with timestamps
  - Easy sharing to other apps

### 4. Attendance Tracking
- **Repository**: `lib/data/local/repositories/event_repository.dart`
- **New Methods**:
  - `getAttendanceCount(eventId)` - Get total attendees for an event
  - `recordAttendance(eventId, userId)` - Record attendance with duplicate check
  - `getAttendanceList(eventId)` - Get full list of attendees
- **Database**: Uses existing `Attendance` table

### 3. Modernized UI Design

#### Events Home Page
- Gradient background (blue to purple)
- Rounded card design with shadows
- Animated FAB (Floating Action Button)
- Modern empty state with gradient icon
- QR generator access button in header

#### Event Attendance Page
- Full gradient background
- Animated entrance (fade + slide)
- Modern stat cards with gradients
- Large, prominent scan button
- Real-time attendance count

#### QR Scanner Page
- Full-screen camera view
- Custom overlay with corner accents
- Dark background with instructions
- Flashlight toggle
- Success dialog with options (Done/Scan Next)

### 4. QR Code Generator (Testing Tool)
- **Location**: `lib/screens/qr_generator_page.dart`
- Simple UI to generate test user IDs
- Copy to clipboard functionality
- Note about using real QR library for production

## Permissions Added

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes for event attendance tracking.</string>
```

## How to Use

### For Event Organizers:
1. Open the app (lands on Events page)
2. Create an event using the "Create Event" button
3. Tap on the event card to open attendance page
4. Tap "Scan QR Code" to start scanning
5. Point camera at attendee's QR code
6. Attendance is recorded automatically
7. Choose "Scan Next" to continue or "Done" to finish

### Viewing Attendance:
1. From the event attendance page, tap "View Attendance List"
2. See all attendees with check-in times
3. Pull down to refresh the list
4. Tap the download icon to export

### Exporting Attendance:
1. Open the attendance list for an event
2. Tap the download icon (top-right)
3. Choose export format:
   - **PDF**: For printing or formal reports
   - **CSV**: For Excel or spreadsheet analysis
4. Share via email, drive, or other apps

### For Testing:
1. Tap the QR icon in the top-right of Events page
2. Enter a test user ID (e.g., "user123")
3. Generate QR code
4. Use a real QR code generator app/website to create actual QR codes with these IDs
5. Scan them in the app

## Design System

### Color Palette
- **Primary Gradient**: Blue (#42A5F5) to Purple (#AB47BC)
- **Success**: Green (#66BB6A) to Teal (#26A69A)
- **Background**: White with subtle gradients
- **Text**: Black87 for primary, Grey600 for secondary

### Typography
- **Headers**: 24-28px, Bold
- **Body**: 14-16px, Regular
- **Buttons**: 16-20px, Bold

### Spacing
- **Cards**: 20-24px padding
- **Sections**: 24-32px margins
- **Elements**: 12-16px gaps

### Animations
- **Duration**: 300-600ms
- **Curves**: easeOut for entrances
- **Types**: Fade, Slide, Scale

## Next Steps (Optional Enhancements)

1. **Real QR Code Generation**
   - Add `qr_flutter` package
   - Generate QR codes for each user profile
   - Display in user profile page

2. **Advanced Filtering**
   - Filter attendance by date range
   - Search attendees by user ID
   - Sort by check-in time

3. **Statistics Dashboard**
   - Attendance trends over time
   - Popular events analysis
   - User participation rates
   - Charts and graphs

4. **Offline Support**
   - Queue scans when offline
   - Sync when connection restored
   - Visual offline indicator

5. **User Profiles**
   - Create user accounts
   - Generate personal QR codes
   - View attendance history

6. **Email Reports**
   - Automated email reports
   - Schedule regular exports
   - Custom report templates

## Technical Notes

- The scanner uses the device's camera through `mobile_scanner`
- Attendance is stored locally in SQLite via Drift
- QR codes should contain user IDs as plain text
- Duplicate attendance is prevented at the repository level
- All UI uses Material Design 3 principles
- Animations use Flutter's built-in animation controllers

## Troubleshooting

### Camera not working
- Check permissions in device settings
- Ensure camera is not being used by another app
- Restart the app

### QR codes not scanning
- Ensure good lighting
- Hold camera steady
- QR code should be clear and not damaged
- Try toggling flashlight

### Attendance not recording
- Check database connection
- Verify event ID is valid
- Check for duplicate attendance
- Review error messages in SnackBar
