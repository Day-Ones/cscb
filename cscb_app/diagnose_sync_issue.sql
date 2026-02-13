-- Comprehensive Sync Diagnostic Script
-- Run this in Supabase SQL Editor to diagnose why events aren't syncing

-- ============================================
-- PART 1: Check what data exists
-- ============================================

SELECT '=== DATA COUNT ===' as section;

SELECT 'Organizations' as table_name, COUNT(*) as count FROM organizations
UNION ALL
SELECT 'Events', COUNT(*) FROM events
UNION ALL
SELECT 'Attendance', COUNT(*) FROM attendance
UNION ALL
SELECT 'Users', COUNT(*) FROM users;

-- ============================================
-- PART 2: Check for orphaned records
-- ============================================

SELECT '=== ORPHANED RECORDS ===' as section;

-- Attendance without events
SELECT 
    'Attendance without Events' as issue,
    COUNT(*) as count
FROM attendance a
LEFT JOIN events e ON a.event_id = e.id
WHERE e.id IS NULL;

-- Events without organizations
SELECT 
    'Events without Organizations' as issue,
    COUNT(*) as count
FROM events e
LEFT JOIN organizations o ON e.org_id = o.id
WHERE o.id IS NULL;

-- ============================================
-- PART 3: Show sample data
-- ============================================

SELECT '=== SAMPLE ATTENDANCE (showing event_id) ===' as section;

SELECT 
    id,
    event_id,
    student_number,
    first_name || ' ' || last_name as student_name,
    timestamp,
    is_synced
FROM attendance
ORDER BY timestamp DESC
LIMIT 5;

SELECT '=== SAMPLE EVENTS ===' as section;

SELECT 
    id,
    org_id,
    name,
    event_date,
    is_synced,
    created_at
FROM events
ORDER BY created_at DESC
LIMIT 5;

SELECT '=== SAMPLE ORGANIZATIONS ===' as section;

SELECT 
    id,
    name,
    status,
    is_synced,
    created_at
FROM organizations
ORDER BY created_at DESC
LIMIT 5;

-- ============================================
-- PART 4: Check foreign key constraints
-- ============================================

SELECT '=== FOREIGN KEY CONSTRAINTS ===' as section;

SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name IN ('events', 'attendance')
ORDER BY tc.table_name, kcu.column_name;

-- ============================================
-- PART 5: Check RLS policies
-- ============================================

SELECT '=== RLS POLICIES ===' as section;

SELECT 
    tablename,
    policyname,
    cmd as operation,
    CASE 
        WHEN qual = 'true' THEN 'Allows all'
        ELSE qual
    END as condition
FROM pg_policies
WHERE tablename IN ('organizations', 'events', 'attendance')
ORDER BY tablename, cmd;

-- ============================================
-- PART 6: Check table structure
-- ============================================

SELECT '=== EVENTS TABLE STRUCTURE ===' as section;

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'events'
ORDER BY ordinal_position;

-- ============================================
-- PART 7: Recommendations
-- ============================================

SELECT '=== RECOMMENDATIONS ===' as section;

-- Check if organizations table is empty
DO $$
DECLARE
    org_count INTEGER;
    event_count INTEGER;
    attendance_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO org_count FROM organizations;
    SELECT COUNT(*) INTO event_count FROM events;
    SELECT COUNT(*) INTO attendance_count FROM attendance;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== DIAGNOSIS ===';
    RAISE NOTICE 'Organizations: %', org_count;
    RAISE NOTICE 'Events: %', event_count;
    RAISE NOTICE 'Attendance: %', attendance_count;
    RAISE NOTICE '';
    
    IF org_count = 0 AND event_count = 0 AND attendance_count > 0 THEN
        RAISE NOTICE '❌ PROBLEM: Attendance exists but no events or organizations!';
        RAISE NOTICE '   This means:';
        RAISE NOTICE '   1. Attendance is syncing ✅';
        RAISE NOTICE '   2. Events are NOT syncing ❌';
        RAISE NOTICE '   3. Organizations are NOT syncing ❌';
        RAISE NOTICE '';
        RAISE NOTICE '💡 SOLUTION:';
        RAISE NOTICE '   Check your Flutter console logs for sync errors.';
        RAISE NOTICE '   Look for messages like:';
        RAISE NOTICE '   - "Failed to sync organization"';
        RAISE NOTICE '   - "Failed to sync event"';
        RAISE NOTICE '';
        RAISE NOTICE '   The sync order should be:';
        RAISE NOTICE '   1. Organizations (must sync first)';
        RAISE NOTICE '   2. Events (depends on organizations)';
        RAISE NOTICE '   3. Attendance (depends on events)';
    ELSIF org_count > 0 AND event_count = 0 AND attendance_count > 0 THEN
        RAISE NOTICE '❌ PROBLEM: Organizations exist but events don''t!';
        RAISE NOTICE '   Events are failing to sync.';
        RAISE NOTICE '   Check console logs for "Failed to sync event" messages.';
    ELSIF org_count > 0 AND event_count > 0 AND attendance_count > 0 THEN
        RAISE NOTICE '✅ SUCCESS: All data is syncing correctly!';
    ELSE
        RAISE NOTICE '⚠️  UNUSUAL: Unexpected data state.';
        RAISE NOTICE '   Organizations: %', org_count;
        RAISE NOTICE '   Events: %', event_count;
        RAISE NOTICE '   Attendance: %', attendance_count;
    END IF;
END $$;
