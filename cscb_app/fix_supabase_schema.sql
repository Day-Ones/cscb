-- Fix Supabase Schema Issues
-- Run this in Supabase SQL Editor

-- 1. Drop the incorrect index on attendance.user_id (column doesn't exist)
DROP INDEX IF EXISTS idx_attendance_user_id;

-- 2. Make created_by nullable and remove foreign key constraint temporarily
-- This allows events to be created without requiring users to exist in Supabase
ALTER TABLE events ALTER COLUMN created_by DROP NOT NULL;
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_created_by_fkey;

-- 3. Check what data exists
SELECT 'Organizations:' as table_name, COUNT(*) as count FROM organizations
UNION ALL
SELECT 'Events:', COUNT(*) FROM events
UNION ALL
SELECT 'Attendance:', COUNT(*) FROM attendance;

-- 4. Check if there are orphaned attendance records (attendance without events)
SELECT 
    'Orphaned Attendance Records:' as issue,
    COUNT(*) as count
FROM attendance a
LEFT JOIN events e ON a.event_id = e.id
WHERE e.id IS NULL;

-- 5. Get the event_id from attendance to see what org_id it should have
SELECT DISTINCT event_id FROM attendance LIMIT 5;

-- 6. Verify events table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'events'
ORDER BY ordinal_position;

-- 7. Verify attendance table structure  
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'attendance'
ORDER BY ordinal_position;

-- 8. Check RLS policies for all tables
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE tablename IN ('organizations', 'events', 'attendance')
ORDER BY tablename, cmd;
