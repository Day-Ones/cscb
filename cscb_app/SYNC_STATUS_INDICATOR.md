# Sync Status Indicator

## Overview

The app now displays a visual indicator showing the current sync status in real-time. Users can see at a glance whether they're online, syncing, or if all data is synced.

## Status Types

### 1. 🔴 Offline (Grey)
- **Icon:** Cloud with slash
- **Text:** "Offline"
- **Meaning:** No internet connection
- **What happens:** Data is saved locally only

### 2. 🔵 Syncing (Blue)
- **Icon:** Spinning progress indicator
- **Text:** "Syncing..."
- **Meaning:** Currently uploading data to Supabase
- **What happens:** Data is being synchronized

### 3. 🟢 Synced (Green)
- **Icon:** Cloud with checkmark
- **Text:** "Synced"
- **Meaning:** All data is backed up to Supabase
- **What happens:** Everything is up to date

### 4. 🔴 Error (Red)
- **Icon:** Cloud with slash
- **Text:** "Sync Error"
- **Meaning:** Sync failed
- **What happens:** Will retry automatically

## Where It Appears

### Events Home Page
- Top right corner of the app bar
- Compact mode (small icon + text)
- Always visible

## Visual Examples

### Compact Mode (Default)
```
┌─────────────────┐
│ 🔵 Syncing...   │
└─────────────────┘
```

### Full Mode
```
┌──────────────────────┐
│  ✓  Synced          │
└──────────────────────┘
```

## Implementation

### Files Created

1. **`lib/widgets/sync_status_indicator.dart`**
   - Reusable widget for displaying sync status
   - Supports compact and full modes
   - Automatically updates when status changes

### Files Modified

2. **`lib/data/sync/auto_sync_manager.dart`**
   - Added `SyncStatus` enum
   - Added status stream for real-time updates
   - Broadcasts status changes to UI

3. **`lib/screens/events_home_page.dart`**
   - Added sync status indicator to app bar
   - Positioned next to QR code button

## Usage

### Basic Usage

```dart
// Compact mode (small, for app bars)
const SyncStatusIndicator(compact: true)

// Full mode (larger, for prominent display)
const SyncStatusIndicator(compact: false)

// Without label (icon only)
const SyncStatusIndicator(showLabel: false)
```

### Adding to Other Screens

To add the sync status indicator to other screens:

```dart
import '../widgets/sync_status_indicator.dart';

// In your build method:
AppBar(
  title: Text('My Screen'),
  actions: [
    const SyncStatusIndicator(compact: true),
    const SizedBox(width: 16),
  ],
)
```

## Status Flow

### Normal Operation
```
App Starts
    ↓
Offline (grey) → Syncing (blue) → Synced (green)
    ↓
Periodic sync every 5 minutes
    ↓
Syncing (blue) → Synced (green)
```

### Connection Lost
```
Synced (green)
    ↓
Connection lost
    ↓
Offline (grey)
    ↓
User continues working
    ↓
Connection restored
    ↓
Syncing (blue) → Synced (green)
```

### Sync Error
```
Syncing (blue)
    ↓
Error occurs
    ↓
Error (red)
    ↓
Auto-retry after 5 minutes
    ↓
Syncing (blue) → Synced (green)
```

## Customization

### Change Colors

Edit `lib/widgets/sync_status_indicator.dart`:

```dart
Color _getStatusColor() {
  switch (_currentStatus) {
    case SyncStatus.offline:
      return Colors.grey;  // Change to your color
    case SyncStatus.syncing:
      return Colors.blue;  // Change to your color
    case SyncStatus.synced:
      return Colors.green; // Change to your color
    case SyncStatus.error:
      return Colors.red;   // Change to your color
  }
}
```

### Change Text

Edit `lib/widgets/sync_status_indicator.dart`:

```dart
String _getStatusText() {
  switch (_currentStatus) {
    case SyncStatus.offline:
      return 'Offline';        // Change text
    case SyncStatus.syncing:
      return 'Syncing...';     // Change text
    case SyncStatus.synced:
      return 'Synced';         // Change text
    case SyncStatus.error:
      return 'Sync Error';     // Change text
  }
}
```

### Change Icons

Edit `lib/widgets/sync_status_indicator.dart`:

```dart
Widget _buildStatusIcon({required double size}) {
  switch (_currentStatus) {
    case SyncStatus.offline:
      return Icon(Icons.cloud_off, ...);      // Change icon
    case SyncStatus.syncing:
      return CircularProgressIndicator(...);  // Or use different icon
    case SyncStatus.synced:
      return Icon(Icons.cloud_done, ...);     // Change icon
    case SyncStatus.error:
      return Icon(Icons.error, ...);          // Change icon
  }
}
```

## Benefits

### 1. User Awareness
- ✅ Users know if they're online or offline
- ✅ Users see when data is being synced
- ✅ Users know when all data is backed up
- ✅ Clear feedback on sync errors

### 2. Trust & Confidence
- ✅ Visual confirmation that data is safe
- ✅ No guessing about sync status
- ✅ Transparent operation

### 3. Troubleshooting
- ✅ Easy to identify connectivity issues
- ✅ Clear indication of sync problems
- ✅ Helps users understand app behavior

## Testing

### Test Status Changes

1. **Start app online:**
   - Should show: Offline → Syncing → Synced

2. **Turn off WiFi:**
   - Should show: Offline (grey)

3. **Turn on WiFi:**
   - Should show: Syncing → Synced

4. **Create event:**
   - Should show: Syncing → Synced

5. **Wait 5 minutes:**
   - Should show: Syncing → Synced (periodic sync)

### Test Visual Appearance

1. **Check colors:**
   - Offline: Grey
   - Syncing: Blue with spinner
   - Synced: Green
   - Error: Red

2. **Check text:**
   - Matches status
   - Readable on background

3. **Check positioning:**
   - Visible in app bar
   - Doesn't overlap other elements

## Troubleshooting

### Indicator not updating?

**Check:**
1. AutoSyncManager is started in main.dart
2. Status stream is working
3. Widget is mounted

**Debug:**
```dart
// Add to _SyncStatusIndicatorState
@override
void initState() {
  super.initState();
  _autoSyncManager.statusStream.listen((status) {
    print('Status changed to: $status');  // Debug log
    if (mounted) {
      setState(() {
        _currentStatus = status;
      });
    }
  });
}
```

### Indicator showing wrong status?

**Check:**
1. Initial status is set correctly
2. Status updates are being broadcast
3. No errors in console

### Indicator not visible?

**Check:**
1. Widget is added to screen
2. Not hidden behind other widgets
3. Colors contrast with background

## Summary

The sync status indicator provides real-time visual feedback about the app's sync state. It helps users understand:

- ✅ Whether they're online or offline
- ✅ When data is being synced
- ✅ When all data is safely backed up
- ✅ If there are any sync errors

**Key Features:**
- Real-time updates
- Clear visual indicators
- Compact and full modes
- Customizable appearance
- Easy to integrate

No configuration needed - it automatically updates based on sync status! 🎨
