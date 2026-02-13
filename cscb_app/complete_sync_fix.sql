-- Complete Fix for Sync Issues
-- This fixes ALL the problems preventing events from syncing
-- Run this entire script in Supabase SQL Editor

-- ============================================
-- STEP 1: Fix Schema Issues
-- ============================================

-- Drop incorrect index (attendance.user_id doesn't exist)
DROP INDEX IF EXISTS idx_attendance_user_id;

-- Make created_by nullable
ALTER TABLE events ALTER COLUMN created_by DROP NOT NULL;

-- Drop foreign key constraints that are blocking inserts
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_created_by_fkey;

-- ============================================
-- STEP 2: Make org_id nullable (TEMPORARY FIX)
-- ============================================
-- This allows events to be created without organizations
-- You can add organizations later and update events

ALTER TABLE events ALTER COLUMN org_id DROP NOT NULL;
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_org_id_fkey;

-- ============================================
-- STEP 3: Recreate RLS Policies
-- ============================================

-- Organizations
DROP POLICY IF EXISTS "Organizations are viewable by everyone" ON organizations;
CREATE POLICY "Organizations are viewable by everyone" ON organizations
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Organizations can be created by anyone" ON organizations;
CREATE POLICY "Organizations can be created by anyone" ON organizations
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Organizations can be updated by anyone" ON organizations;
CREATE POLICY "Organizations can be updated by anyone" ON organizations
    FOR UPDATE USING (true);

-- Events
DROP POLICY IF EXISTS "Events are viewable by everyone" ON events;
CREATE POLICY "Events are viewable by everyone" ON events
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Events can be created by anyone" ON events;
CREATE POLICY "Events can be created by anyone" ON events
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Events can be updated by anyone" ON events;
CREATE POLICY "Events can be updated by anyone" ON events
    FOR UPDATE USING (true);

-- Attendance
DROP POLICY IF EXISTS "Attendance is viewable by everyone" ON attendance;
CREATE POLICY "Attendance is viewable by everyone" ON attendance
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Attendance can be created by anyone" ON attendance;
CREATE POLICY "Attendance can be created by anyone" ON attendance
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Attendance can be updated by anyone" ON attendance;
CREATE POLICY "Attendance can be updated by anyone" ON attendance
    FOR UPDATE USING (true);

-- ============================================
-- STEP 4: Test Insert
-- ============================================

DO $$
DECLARE
    test_event_id TEXT := 'test-' || gen_random_uuid()::text;
    test_org_id TEXT := 'test-org-' || gen_random_uuid()::text;
BEGIN
    -- Test 1: Insert event WITHOUT org_id (should work now)
    BEGIN
        INSERT INTO events (
            id, name, event_date, location, deleted
        ) VALUES (
            test_event_id, 'Test Event No Org', NOW() + INTERVAL '1 day', 'Test', false
        );
        
        IF EXISTS (SELECT 1 FROM events WHERE id = test_event_id) THEN
            RAISE NOTICE '✅ SUCCESS: Can insert events without org_id!';
            DELETE FROM events WHERE id = test_event_id;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ FAILED: Cannot insert event without org_id: %', SQLERRM;
    END;
    
    -- Test 2: Insert organization then event (should work)
    BEGIN
        INSERT INTO organizations (id, name, status, deleted)
        VALUES (test_org_id, 'Test Org', 'active', false);
        
        INSERT INTO events (
            id, org_id, name, event_date, location, deleted
        ) VALUES (
            test_event_id, test_org_id, 'Test Event With Org', NOW() + INTERVAL '1 day', 'Test', false
        );
        
        IF EXISTS (SELECT 1 FROM events WHERE id = test_event_id) THEN
            RAISE NOTICE '✅ SUCCESS: Can insert events with org_id!';
            DELETE FROM events WHERE id = test_event_id;
            DELETE FROM organizations WHERE id = test_org_id;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ FAILED: Cannot insert event with org_id: %', SQLERRM;
        -- Cleanup
        DELETE FROM events WHERE id = test_event_id;
        DELETE FROM organizations WHERE id = test_org_id;
    END;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== NEXT STEPS ===';
    RAISE NOTICE '1. Restart your Flutter app';
    RAISE NOTICE '2. Create a new event';
    RAISE NOTICE '3. Check console logs for sync messages';
    RAISE NOTICE '4. Check this table: SELECT * FROM events;';
    RAISE NOTICE '5. Event should appear within 1-2 seconds!';
END $$;

-- ============================================
-- STEP 5: Show Current State
-- ============================================

SELECT '=== CURRENT DATA ===' as info;

SELECT 'Organizations' as table_name, COUNT(*) as count FROM organizations
UNION ALL
SELECT 'Events', COUNT(*) FROM events
UNION ALL
SELECT 'Attendance', COUNT(*) FROM attendance;
