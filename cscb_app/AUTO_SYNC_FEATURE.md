# Automatic Sync Feature

## Overview

The app now automatically syncs data to Supabase when internet connection is detected, without waiting for user actions like scanning QR codes.

## How It Works

### 1. Connectivity Monitoring
- Monitors internet connection status in real-time
- Detects when connection is restored
- Automatically triggers sync when coming back online

### 2. Automatic Sync Triggers

**When sync happens:**
- ✅ App starts with internet connection
- ✅ Internet connection is restored after being offline
- ✅ Every 5 minutes (periodic sync when online)
- ✅ Immediately after QR scan (instant feedback)
- ✅ Immediately after event creation (instant feedback)

### 3. Smart Sync Management

**Features:**
- Debouncing to prevent multiple simultaneous syncs
- Background operation (doesn't block UI)
- Detailed logging for debugging
- Graceful error handling

## Implementation

### New Files Created

1. **`lib/data/sync/auto_sync_manager.dart`**
   - Monitors connectivity using `connectivity_plus` package
   - Triggers sync automatically
   - Manages periodic sync timer
   - Prevents duplicate sync operations

### Modified Files

2. **`pubspec.yaml`**
   - Added `connectivity_plus: ^6.0.0` dependency

3. **`lib/core/di/locator.dart`**
   - Registered `AutoSyncManager` as singleton

4. **`lib/main.dart`**
   - Starts `AutoSyncManager` on app launch

## Usage

### Automatic (No Code Needed)

The sync manager starts automatically when the app launches. No additional code needed!

### Manual Sync (Optional)

If you want to add a pull-to-refresh feature:

```dart
final autoSyncManager = getIt<AutoSyncManager>();
await autoSyncManager.manualSync();
```

## Sync Flow

### Scenario 1: App Starts Online
```
1. App launches
2. AutoSyncManager checks connectivity → Online
3. Triggers initial sync
4. Syncs all unsynced data (events, attendance)
5. Sets up periodic sync (every 5 minutes)
```

### Scenario 2: App Starts Offline
```
1. App launches
2. AutoSyncManager checks connectivity → Offline
3. Waits for connection
4. User works offline (data saved locally)
5. Connection restored
6. AutoSyncManager detects connection
7. Automatically syncs all pending data
```

### Scenario 3: Connection Lost and Restored
```
1. App running online
2. Connection lost
3. User continues working (offline mode)
4. Data saved to local SQLite
5. Connection restored
6. AutoSyncManager detects connection
7. Automatically syncs pending data
8. No user action required!
```

## Console Logs

You'll see these messages in the console:

### Normal Operation
```
AutoSync: Online - triggering initial sync
AutoSync: ✅ All data synced successfully
AutoSync: Periodic sync triggered
```

### Connection Changes
```
AutoSync: Connectivity changed - Online: false
AutoSync: Offline - waiting for connection
AutoSync: Connectivity changed - Online: true
AutoSync: Connection restored - triggering sync
```

### Sync Status
```
AutoSync: Sync already in progress, skipping
AutoSync: ✅ All data synced successfully
AutoSync: ❌ Sync failed: [error message]
```

## Benefits

### 1. Better User Experience
- ✅ No need to manually trigger sync
- ✅ Data syncs automatically when online
- ✅ Works seamlessly in offline mode
- ✅ Automatic retry when connection restored

### 2. Data Reliability
- ✅ Periodic sync ensures data is backed up
- ✅ Immediate sync after important actions
- ✅ Automatic retry on connection restore
- ✅ No data loss even with poor connectivity

### 3. Multi-Device Support
- ✅ Data syncs across devices automatically
- ✅ Latest data always available
- ✅ Conflict resolution (earlier timestamp wins)

## Configuration

### Sync Interval

To change the periodic sync interval, edit `auto_sync_manager.dart`:

```dart
// Current: Every 5 minutes
_syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {

// Change to 10 minutes:
_syncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
```

### Disable Periodic Sync

If you only want sync on connection restore (not periodic):

```dart
// Comment out or remove this section in auto_sync_manager.dart:
// _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
//   if (_isOnline && !_isSyncing) {
//     debugPrint('AutoSync: Periodic sync triggered');
//     _triggerSync();
//   }
// });
```

## Testing

### Test Automatic Sync

1. **Start app offline:**
   - Turn off WiFi/mobile data
   - Launch app
   - Create event or scan QR code
   - Check console: "AutoSync: Offline - waiting for connection"

2. **Restore connection:**
   - Turn on WiFi/mobile data
   - Check console: "AutoSync: Connection restored - triggering sync"
   - Check Supabase: Data should appear

3. **Test periodic sync:**
   - Keep app running online
   - Wait 5 minutes
   - Check console: "AutoSync: Periodic sync triggered"

### Test Immediate Sync

1. **With internet:**
   - Scan QR code
   - Check console: Immediate sync + AutoSync messages
   - Check Supabase: Data appears instantly

2. **Without internet:**
   - Turn off connection
   - Scan QR code
   - Data saved locally
   - Turn on connection
   - AutoSync automatically syncs

## Troubleshooting

### Sync not happening automatically?

**Check console logs:**
```bash
flutter run
# Look for AutoSync messages
```

**Verify connectivity package:**
```bash
flutter pub get
```

**Check permissions (Android):**
Ensure `AndroidManifest.xml` has:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

### Multiple syncs happening?

This is normal! The app syncs:
- Immediately after actions (QR scan, event creation)
- When connection is restored
- Every 5 minutes (periodic)

The debouncing prevents duplicate simultaneous syncs.

### Sync failing?

Check:
1. Supabase credentials in `lib/core/config/supabase_config.dart`
2. Supabase tables exist (run migration)
3. RLS policies allow anonymous access
4. Internet connection is stable

## Summary

The automatic sync feature ensures your data is always backed up to Supabase without requiring manual intervention. It works seamlessly in both online and offline modes, providing a reliable and user-friendly experience.

**Key Features:**
- ✅ Automatic sync on connection restore
- ✅ Periodic sync every 5 minutes
- ✅ Immediate sync after important actions
- ✅ Smart debouncing
- ✅ Background operation
- ✅ Detailed logging

No configuration needed - it just works! 🎉
