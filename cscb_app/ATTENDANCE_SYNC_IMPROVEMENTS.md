# Attendance Sync Improvements

## Changes Made

### 1. Removed user_id from Attendance Table

**Why user_id was removed:**
- The app doesn't have user authentication
- QR codes contain student information (student number, name, program, year)
- The `user_id` field was redundantly storing the student number
- For attendance tracking, we only need: `event_id` + `student_number` + `timestamp`
- Simpler schema = easier to maintain and understand

**Before:**
```dart
class Attendance extends Table {
  TextColumn get eventId => text()();
  TextColumn get userId => text()();  // ❌ Redundant!
  TextColumn get studentNumber => text()();
  // ... other fields
}
```

**After:**
```dart
class Attendance extends Table {
  TextColumn get eventId => text()();
  TextColumn get studentNumber => text()();  // ✅ This is all we need!
  // ... other fields
}
```

### 2. Added Duplicate Prevention Logic

**Problem:** When multiple devices scan the same student's QR code for the same event, duplicate attendance records could be created.

**Solution:** The sync service now:
1. Checks if attendance already exists in Supabase for that student + event
2. If duplicate found, compares timestamps
3. Keeps the EARLIER attendance record (first scan wins)
4. Updates Supabase if local record is earlier

**How it works:**

```dart
// When syncing attendance
if (existingAttendance != null) {
  // Duplicate found - compare timestamps
  if (localTimestamp.isBefore(existingTimestamp)) {
    // Local is earlier - update Supabase
    await updateAttendance(id, {timestamp: localTimestamp});
  } else {
    // Remote is earlier - keep it, just mark local as synced
  }
} else {
  // No duplicate - create new record
  await createAttendance(attendance);
}
```

### 3. Added Database Constraint

Added a UNIQUE constraint in Supabase to prevent duplicates at the database level:

```sql
UNIQUE(event_id, student_number)
```

This ensures that even if sync logic fails, the database won't allow duplicate attendance records.

## Database Schema Changes

### Local Database (SQLite)
- Removed `userId` column from `Attendance` table
- Schema version bumped from 6 to 7
- Migration automatically recreates the table

### Supabase Database
- Removed `user_id` column from `attendance` table
- Added `UNIQUE(event_id, student_number)` constraint
- Run `supabase_sync_migration.sql` to apply changes

## Files Modified

### Core Changes
1. `lib/data/local/db/app_database.dart`
   - Removed `userId` from Attendance table
   - Added migration from version 6 to 7

2. `lib/data/local/repositories/event_repository.dart`
   - Removed `userId` parameter when inserting attendance

3. `lib/data/sync/sync_service.dart`
   - Added duplicate detection logic
   - Prioritizes earlier attendance records
   - Removed `user_id` from sync data

4. `lib/data/remote/repositories/remote_attendance_repository.dart`
   - Added `getAttendanceByEventAndStudent()` method for duplicate checking

### Schema Files
5. `supabase_schema.sql`
   - Removed `user_id` column
   - Added UNIQUE constraint

6. `supabase_sync_migration.sql`
   - Complete migration script for Supabase
   - Recreates attendance table without user_id
   - Adds unique constraint

## Testing the Changes

### 1. Test Duplicate Prevention

**Scenario:** Two devices scan the same student at different times

**Steps:**
1. Device A scans student at 10:00 AM
2. Device B scans same student at 10:05 AM
3. Both devices sync to Supabase

**Expected Result:**
- Only one attendance record in Supabase
- Timestamp shows 10:00 AM (earlier time)
- Both devices show `isSynced: true`

### 2. Test Without user_id

**Steps:**
1. Create an event
2. Scan a student QR code
3. Check local database - no `user_id` column
4. Check Supabase - no `user_id` column
5. Verify attendance is recorded correctly

## Migration Steps

### For Local Database
No action needed! The app will automatically migrate when you run it.

### For Supabase Database

**Option 1: Fresh Start (No existing data)**
```sql
-- Run supabase_sync_migration.sql in Supabase SQL Editor
-- This drops and recreates the attendance table
```

**Option 2: Preserve Existing Data**
```sql
-- 1. Export existing attendance data
SELECT * FROM attendance;

-- 2. Run the migration
-- (Run supabase_sync_migration.sql)

-- 3. Re-import data (if needed)
-- Manually insert important records
```

## Benefits

### 1. Simpler Schema
- ✅ Removed unnecessary `user_id` column
- ✅ Clearer data model
- ✅ Easier to understand and maintain

### 2. Duplicate Prevention
- ✅ No duplicate attendance records
- ✅ Earlier timestamp always wins
- ✅ Works across multiple devices
- ✅ Database-level constraint as backup

### 3. Better Sync Logic
- ✅ Intelligent duplicate detection
- ✅ Timestamp comparison
- ✅ Automatic conflict resolution
- ✅ Detailed logging for debugging

## Example Data Flow

### Scenario: Student scanned on two devices

**Device A (10:00 AM):**
```json
{
  "id": "att_123",
  "event_id": "evt_456",
  "student_number": "2023-00495-TG-0",
  "first_name": "Daniel",
  "last_name": "Victorioso",
  "program": "DIT 3-1",
  "year_level": 3,
  "timestamp": "2026-02-13T10:00:00Z"
}
```

**Device B (10:05 AM):**
```json
{
  "id": "att_789",
  "event_id": "evt_456",
  "student_number": "2023-00495-TG-0",
  "first_name": "Daniel",
  "last_name": "Victorioso",
  "program": "DIT 3-1",
  "year_level": 3,
  "timestamp": "2026-02-13T10:05:00Z"
}
```

**After Sync:**
```json
{
  "id": "att_123",
  "event_id": "evt_456",
  "student_number": "2023-00495-TG-0",
  "first_name": "Daniel",
  "last_name": "Victorioso",
  "program": "DIT 3-1",
  "year_level": 3,
  "timestamp": "2026-02-13T10:00:00Z"  // ✅ Earlier time kept
}
```

## Troubleshooting

### Error: "duplicate key value violates unique constraint"

This is expected! It means the unique constraint is working.

**Solution:** The sync service handles this automatically by checking for duplicates before inserting.

### Local attendance not syncing

**Check:**
1. Is `isSynced` false in local database?
2. Are there any error messages in console?
3. Is Supabase reachable?

**Debug:**
```bash
flutter run
# Look for: "Failed to sync attendance [id]: [error]"
```

### Timestamp not updating to earlier time

**Check:**
1. Is the local timestamp actually earlier?
2. Check console logs for "Updated Supabase with earlier attendance"
3. Verify the `getAttendanceByEventAndStudent()` method is working

## Summary

These changes make the attendance system:
- **Simpler** - Removed unnecessary user_id field
- **More reliable** - Duplicate prevention with timestamp priority
- **More robust** - Database-level unique constraint
- **Better for multi-device** - Handles concurrent scans gracefully

The earlier attendance record always wins, ensuring accurate "first scan" timestamps.
