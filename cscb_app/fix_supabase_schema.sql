-- Fix Supabase Schema Issues
-- Run this in Supabase SQL Editor

-- 1. Drop the incorrect index on attendance.user_id (column doesn't exist)
DROP INDEX IF EXISTS idx_attendance_user_id;

-- 2. Make created_by nullable and remove foreign key constraint temporarily
-- This allows events to be created without requiring users to exist in Supabase
ALTER TABLE events ALTER COLUMN created_by DROP NOT NULL;
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_created_by_fkey;

-- 3. Verify events table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'events'
ORDER BY ordinal_position;

-- 4. Verify attendance table structure  
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'attendance'
ORDER BY ordinal_position;

-- 5. Check if there are any failed inserts in logs
-- (This is just informational - check your Supabase logs for errors)

-- 6. Test inserting a sample event
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
    'test-event-' || gen_random_uuid()::text,
    'test-org-id',
    'Test Event',
    'This is a test event',
    NOW() + INTERVAL '1 day',
    'Test Location',
    100,
    'test-user-id',
    false,
    false
);

-- 7. Verify the test event was inserted
SELECT * FROM events WHERE name = 'Test Event';

-- 8. Clean up test event
DELETE FROM events WHERE name = 'Test Event';

-- 9. Show current RLS policies for events
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'events';
