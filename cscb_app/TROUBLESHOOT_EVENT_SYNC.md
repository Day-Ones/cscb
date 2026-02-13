# Troubleshooting: Events Not Syncing to Supabase

## Problem

- Attendance records ARE syncing to Supabase ✅
- Events are NOT syncing to Supabase ❌
- Events exist in local database but not in Supabase
- Attendance has event_id but no corresponding event in Supabase

## Root Causes

There are several possible issues:

### 1. Schema Issues (Most Likely)

The `supabase_schema.sql` has an error:
```sql
CREATE INDEX IF NOT EXISTS idx_attendance_user_id ON attendance(user_id);
```

This tries to create an index on `user_id` column that **doesn't exist** in the attendance table (we removed it).

### 2. Foreign Key Constraint

Events table has:
```sql
created_by TEXT REFERENCES users(id)
```

If the user doesn't exist in Supabase, the insert will fail.

### 3. Silent Errors

The sync service catches errors but only prints them:
```dart
catch (e) {
  debugPrint('Failed to sync event ${event.name}: $e');
  // Continue with next event
}
```

## Solution Steps

### Step 1: Fix the Schema

Run this in Supabase SQL Editor:

```sql
-- Fix Supabase Schema Issues

-- 1. Drop the incorrect index
DROP INDEX IF EXISTS idx_attendance_user_id;

-- 2. Make created_by nullable (allows events without users)
ALTER TABLE events ALTER COLUMN created_by DROP NOT NULL;

-- 3. Drop foreign key constraint temporarily
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_created_by_fkey;

-- 4. Verify events table is ready
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'events'
ORDER BY ordinal_position;
```

### Step 2: Check Console Logs

Look for error messages in your Flutter console:

```
Failed to sync event [event_name]: [error message]
```

Common errors:
- `violates foreign key constraint` - User doesn't exist
- `column "user_id" does not exist` - Schema mismatch
- `permission denied` - RLS policy issue
- `null value in column` - Missing required field

### Step 3: Manually Test Event Insert

In Supabase SQL Editor:

```sql
-- Test inserting an event manually
INSERT INTO events (
    id,
    org_id,
    name,
    description,
    event_date,
    location,
    max_attendees,
    created_by,
    is_synced,
    deleted
) VALUES (
    gen_random_uuid()::text,
    'test-org',
    'Manual Test Event',
    'Testing manual insert',
    NOW() + INTERVAL '1 day',
    'Test Location',
    50,
    NULL,  -- NULL is OK now
    false,
    false
);

-- Check if it worked
SELECT * FROM events WHERE name = 'Manual Test Event';

-- Clean up
DELETE FROM events WHERE name = 'Manual Test Event';
```

If this fails, you'll see the exact error message.

### Step 4: Check RLS Policies

Verify RLS policies allow inserts:

```sql
-- Check current policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'events';

-- Should see:
-- "Events can be created by anyone" FOR INSERT WITH CHECK (true)
```

If the policy is missing, add it:

```sql
CREATE POLICY "Events can be created by anyone" ON events
    FOR INSERT WITH CHECK (true);
```

### Step 5: Trigger Manual Sync

In your app:

1. Create a new event
2. Check console logs immediately
3. Look for "Failed to sync event" messages
4. Note the exact error

### Step 6: Check Local Database

Verify events are marked as unsynced:

In your app, you can add debug logging:

```dart
// In sync_service.dart, add before the loop:
debugPrint('Found ${unsyncedEvents.length} unsynced events');
for (var event in unsyncedEvents) {
  debugPrint('Unsynced event: ${event.name} (${event.id})');
}
```

## Quick Fix Script

Run this complete fix in Supabase SQL Editor:

```sql
-- Complete Fix for Event Sync Issues

-- 1. Drop incorrect index
DROP INDEX IF NOT EXISTS idx_attendance_user_id;

-- 2. Fix events table constraints
ALTER TABLE events ALTER COLUMN created_by DROP NOT NULL;
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_created_by_fkey;

-- 3. Ensure RLS policies exist
DROP POLICY IF EXISTS "Events can be created by anyone" ON events;
CREATE POLICY "Events can be created by anyone" ON events
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Events can be updated by anyone" ON events;
CREATE POLICY "Events can be updated by anyone" ON events
    FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Events are viewable by everyone" ON events;
CREATE POLICY "Events are viewable by everyone" ON events
    FOR SELECT USING (true);

-- 4. Verify table structure
\d events

-- 5. Test insert
DO $$
DECLARE
    test_id TEXT := 'test-' || gen_random_uuid()::text;
BEGIN
    INSERT INTO events (
        id, org_id, name, event_date, location, deleted
    ) VALUES (
        test_id, 'test-org', 'Test Event', NOW() + INTERVAL '1 day', 'Test', false
    );
    
    IF EXISTS (SELECT 1 FROM events WHERE id = test_id) THEN
        RAISE NOTICE 'SUCCESS: Event insert works!';
        DELETE FROM events WHERE id = test_id;
    ELSE
        RAISE EXCEPTION 'FAILED: Event was not inserted';
    END IF;
END $$;
```

## After Fixing

1. Run the fix script in Supabase
2. Restart your Flutter app
3. Create a new event
4. Check console logs
5. Check Supabase Table Editor → events
6. Event should appear within 1-2 seconds

## Verification Queries

### Check if events are syncing now

```sql
-- Events created in last hour
SELECT 
    name,
    event_date,
    created_at,
    is_synced
FROM events 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
```

### Check orphaned attendance (attendance without events)

```sql
-- Attendance records with no matching event
SELECT 
    a.id,
    a.event_id,
    a.student_number,
    a.timestamp
FROM attendance a
LEFT JOIN events e ON a.event_id = e.id
WHERE e.id IS NULL;
```

If you see orphaned attendance, those events failed to sync.

## Still Not Working?

If events still don't sync after the fix:

1. **Check Supabase logs**: Dashboard → Logs → Look for errors
2. **Check network**: Ensure device has internet
3. **Check Supabase URL**: Verify `lib/core/config/supabase_config.dart` has correct URL
4. **Check API key**: Verify anon key is correct
5. **Add more logging**: Add `debugPrint` statements in `syncEvents()` method

## Prevention

To prevent this in the future:

1. Always test schema changes in Supabase before deploying
2. Check console logs after creating events
3. Verify data in Supabase Table Editor
4. Use `fix_supabase_schema.sql` for clean setup

## Summary

The most likely issue is the incorrect index on `attendance.user_id` causing schema setup to fail. Run the fix script and events should start syncing immediately.
