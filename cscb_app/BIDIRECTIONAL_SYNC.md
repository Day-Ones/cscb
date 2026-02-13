# Bi-Directional Sync Implementation

## Overview

The app now supports **bi-directional sync** between local SQLite and Supabase. This allows multiple devices to collaborate on the same events and see each other's attendance records in real-time.

## How It Works

### Sync Flow

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│  Device 1   │         │  Supabase   │         │  Device 2   │
│   (Local)   │         │  (Remote)   │         │   (Local)   │
└─────────────┘         └─────────────┘         └─────────────┘
      │                        │                        │
      │  1. Push local changes │                        │
      ├───────────────────────>│                        │
      │                        │                        │
      │  2. Pull remote changes│                        │
      │<───────────────────────┤                        │
      │                        │                        │
      │                        │  3. Pull remote changes│
      │                        │<───────────────────────┤
      │                        │                        │
      │                        │  4. Device 2 sees      │
      │                        │     Device 1's data    │
      │                        │                        │
```

### Two-Phase Sync

Each sync operation has two phases:

1. **Push Phase** (Local → Remote)
   - Upload unsynced local changes to Supabase
   - Handle conflicts (keep earlier timestamps)
   - Mark local records as synced

2. **Pull Phase** (Remote → Local)
   - Download new/updated records from Supabase
   - Merge with local data
   - Handle conflicts (keep earlier timestamps)

## Conflict Resolution

### For Events

**Scenario**: Device 1 and Device 2 both modify the same event offline

**Resolution**:
- Compare `client_updated_at` timestamps
- Keep the **newer** version (most recent edit wins)
- Update local database with remote changes if remote is newer

### For Attendance

**Scenario**: Device 1 and Device 2 both scan the same student

**Resolution**:
- Compare `timestamp` (when student was scanned)
- Keep the **earlier** timestamp (first scan wins)
- This ensures the earliest attendance time is recorded

## Use Cases

### Use Case 1: Multiple Devices Recording Attendance

**Scenario**:
- Device 1 creates an event and syncs it
- Device 2 pulls the event and sees it in their list
- Both devices can now record attendance for the same event
- All attendance records sync to Supabase
- Both devices see all attendance records

**Steps**:
1. Device 1: Create event "CS Club Meeting"
2. Device 1: Sync (event pushed to Supabase)
3. Device 2: Sync (event pulled from Supabase)
4. Device 2: Scan Student A at 2:00 PM
5. Device 1: Scan Student B at 2:05 PM
6. Both devices sync
7. Both devices now see both Student A and Student B

### Use Case 2: Offline Recording with Later Sync

**Scenario**:
- Device 1 goes offline
- Device 1 records attendance while offline
- Device 2 is online and records attendance
- Device 1 comes back online and syncs

**Steps**:
1. Device 1: Goes offline
2. Device 1: Scan Student A at 2:00 PM (saved locally)
3. Device 2: Scan Student B at 2:05 PM (synced immediately)
4. Device 1: Comes back online
5. Device 1: Auto-sync triggers
6. Device 1: Pushes Student A to Supabase
7. Device 1: Pulls Student B from Supabase
8. Both devices now have complete attendance

### Use Case 3: Duplicate Prevention Across Devices

**Scenario**:
- Device 1 scans Student A at 2:00 PM
- Device 2 scans Student A at 2:10 PM (duplicate)
- System keeps the earlier timestamp

**Steps**:
1. Device 1: Scan Student A at 2:00 PM
2. Device 1: Sync (pushed to Supabase)
3. Device 2: Scan Student A at 2:10 PM
4. Device 2: Sync
5. System detects duplicate (same event + student)
6. System keeps 2:00 PM timestamp (earlier)
7. Device 2's 2:10 PM scan is marked as synced but not stored

## Technical Details

### Push Methods

- `syncEvents()` - Push local events to Supabase
- `syncAttendance()` - Push local attendance to Supabase

### Pull Methods

- `pullEvents()` - Pull remote events to local
- `pullAttendance()` - Pull remote attendance to local

### Sync Order

```dart
Future<SyncResult> syncAll() async {
  // Phase 1: Push local changes
  await syncUsers();
  await syncOrganizations();
  await syncEvents();
  await syncAttendance();
  
  // Phase 2: Pull remote changes
  await pullEvents();
  await pullAttendance();
  
  return SyncResult.success('All data synced successfully');
}
```

## Automatic Sync Triggers

Sync happens automatically when:

1. **Connection restored** - When device comes back online
2. **Periodic sync** - Every 5 minutes when online
3. **Manual trigger** - When user explicitly syncs

## Data Flow Examples

### Example 1: Event Creation

```
Device 1                    Supabase                    Device 2
--------                    --------                    --------
Create event
  ↓
Mark as unsynced
  ↓
Sync triggered
  ↓
Push event ──────────────→ Store event
                              ↓
                           Event exists
                              ↓
                           Sync triggered ←────────── Device 2 online
                              ↓
Pull event ←────────────── Return event
  ↓
Store locally
  ↓
Event visible
```

### Example 2: Attendance Recording

```
Device 1                    Supabase                    Device 2
--------                    --------                    --------
Scan Student A (2:00 PM)
  ↓
Store locally
  ↓
Sync ────────────────────→ Store attendance
                              ↓
                                                    Sync triggered
                              ↓
                           Return attendance ──────→ Pull attendance
                                                       ↓
                                                    Store locally
                                                       ↓
                                                    Student A visible
```

## Benefits

✅ **Multi-device collaboration** - Multiple devices can work on same event
✅ **Real-time visibility** - See attendance from other devices
✅ **Offline-first** - Still works without internet
✅ **Conflict resolution** - Smart handling of duplicates
✅ **Data integrity** - Earlier timestamps preserved
✅ **Automatic sync** - No manual intervention needed

## Limitations

⚠️ **Sync delay** - Changes visible after sync (not instant)
⚠️ **Conflict window** - Brief period where conflicts can occur
⚠️ **Network required** - Pull sync needs internet connection
⚠️ **Storage growth** - Local database grows with remote data

## Testing

### Test Scenario 1: Two Devices, One Event

1. Device 1: Create event "Test Event"
2. Device 1: Sync
3. Device 2: Sync
4. Device 2: Verify event appears
5. Device 2: Scan Student A
6. Device 2: Sync
7. Device 1: Sync
8. Device 1: Verify Student A appears

### Test Scenario 2: Offline Recording

1. Device 1: Turn off WiFi
2. Device 1: Scan Student A
3. Device 1: Verify saved locally
4. Device 1: Turn on WiFi
5. Device 1: Wait for auto-sync
6. Device 1: Check Supabase - Student A should appear

### Test Scenario 3: Duplicate Prevention

1. Device 1: Scan Student A at 2:00 PM
2. Device 1: Sync
3. Device 2: Sync (pulls Student A)
4. Device 2: Scan Student A at 2:10 PM
5. Device 2: Sync
6. Check Supabase: Only one record with 2:00 PM timestamp

## Console Logs

Look for these messages:

```
✅ Pulled new event: CS Club Meeting
✅ Pulled new attendance: 2023-00495-TG-0
✅ Updated local with earlier remote attendance for 2023-00495-TG-0
✅ Updated Supabase with earlier attendance for 2023-00495-TG-0
✅ AutoSync: ✅ All data synced successfully
```

## Summary

Bi-directional sync enables true multi-device collaboration while maintaining offline-first capabilities. The system intelligently handles conflicts by keeping earlier timestamps for attendance and newer updates for events, ensuring data integrity across all devices.
