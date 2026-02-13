# Supabase Sync Setup - Anonymous Mode

## Overview
The app now syncs events and attendance to Supabase without requiring user authentication. This allows the app to remain simple (no login) while still backing up data to the cloud.

## Changes Made

### 1. New Files Created
- `lib/data/remote/repositories/remote_attendance_repository.dart` - Handles attendance sync to Supabase

### 2. Files Modified

#### `lib/data/sync/sync_service.dart`
- Added `RemoteEventRepository` and `RemoteAttendanceRepository` dependencies
- Added `syncEvents()` method to sync events to Supabase
- Added `syncAttendance()` method to sync attendance to Supabase
- Updated `syncAll()` to include events and attendance

#### `lib/core/di/locator.dart`
- Registered `RemoteEventRepository`
- Registered `RemoteAttendanceRepository`
- Registered `SyncService` with all dependencies

#### `lib/screens/events_home_page.dart`
- Added `SyncService` dependency
- Calls `syncEvents()` after creating an event
- Syncs in background (doesn't block UI)

#### `lib/screens/qr_scanner_page.dart`
- Added `SyncService` dependency
- Calls `syncAttendance()` after recording attendance
- Syncs in background (doesn't block UI)

## How It Works

### Event Creation Flow
1. User creates event → Saved to local SQLite database
2. Event marked as `isSynced: false`
3. `syncEvents()` called in background
4. Event synced to Supabase using anonymous key
5. Local record marked as `isSynced: true`

### Attendance Recording Flow
1. User scans QR code → Attendance saved to local SQLite database
2. Attendance marked as `isSynced: false`
3. `syncAttendance()` called in background
4. Attendance synced to Supabase using anonymous key
5. Local record marked as `isSynced: true`

## Supabase Configuration

### Required Tables

**events table:**
```sql
CREATE TABLE events (
  id TEXT PRIMARY KEY,
  org_id TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  event_date TIMESTAMP WITH TIME ZONE NOT NULL,
  location TEXT NOT NULL,
  max_attendees INTEGER,
  created_by TEXT NOT NULL,
  is_synced BOOLEAN DEFAULT FALSE,
  client_updated_at TIMESTAMP WITH TIME ZONE,
  deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**attendance table:**
```sql
CREATE TABLE attendance (
  id TEXT PRIMARY KEY,
  event_id TEXT REFERENCES events(id),
  user_id TEXT NOT NULL,
  student_number TEXT NOT NULL,
  last_name TEXT NOT NULL,
  first_name TEXT NOT NULL,
  program TEXT NOT NULL,
  year_level INTEGER NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
  status TEXT DEFAULT 'present',
  is_synced BOOLEAN DEFAULT FALSE,
  client_updated_at TIMESTAMP WITH TIME ZONE,
  deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Row Level Security (RLS)

Since the app uses anonymous access, you need to set up RLS policies:

**For events table:**
```sql
-- Allow anonymous users to insert events
CREATE POLICY "Allow anonymous insert" ON events
  FOR INSERT TO anon
  WITH CHECK (true);

-- Allow anonymous users to read events
CREATE POLICY "Allow anonymous select" ON events
  FOR SELECT TO anon
  USING (deleted = false);

-- Allow anonymous users to update events
CREATE POLICY "Allow anonymous update" ON events
  FOR UPDATE TO anon
  USING (true);
```

**For attendance table:**
```sql
-- Allow anonymous users to insert attendance
CREATE POLICY "Allow anonymous insert" ON attendance
  FOR INSERT TO anon
  WITH CHECK (true);

-- Allow anonymous users to read attendance
CREATE POLICY "Allow anonymous select" ON attendance
  FOR SELECT TO anon
  USING (deleted = false);

-- Allow anonymous users to update attendance
CREATE POLICY "Allow anonymous update" ON attendance
  FOR UPDATE TO anon
  USING (true);
```

## Testing

### 1. Verify Supabase Connection
Check that Supabase is initialized in `main.dart`:
```dart
await SupabaseService.initialize();
```

### 2. Create an Event
1. Open the app
2. Create a new event
3. Check Supabase dashboard → events table
4. Event should appear within a few seconds

### 3. Record Attendance
1. Open an event
2. Scan a QR code
3. Check Supabase dashboard → attendance table
4. Attendance record should appear within a few seconds

### 4. Check Sync Status
Events and attendance are marked as synced in the local database:
- `isSynced = true` means successfully synced to Supabase
- `isSynced = false` means pending sync

## Error Handling

- Sync failures are logged to console (debugPrint)
- Sync happens in background - doesn't block UI
- Failed syncs can be retried by calling `syncAll()`
- Local data is preserved even if sync fails

## Benefits

✅ No login required - app remains simple
✅ Data backed up to cloud automatically
✅ Multiple devices can share data via Supabase
✅ Offline-first - works without internet
✅ Background sync - doesn't slow down UI
✅ Automatic retry on app restart

## Limitations

⚠️ Anonymous access means no user-specific data
⚠️ Anyone with the anon key can read/write data
⚠️ Consider adding authentication for production use
⚠️ No conflict resolution for concurrent edits

## Next Steps

1. Verify Supabase tables exist
2. Set up RLS policies
3. Test event creation and sync
4. Test attendance recording and sync
5. Monitor Supabase dashboard for data

---

**Note**: For production use, consider adding authentication to secure the data and enable user-specific features.
