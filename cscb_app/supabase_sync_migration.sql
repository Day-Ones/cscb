-- Migration to update attendance table for sync support
-- This script safely modifies the existing table without losing data
-- Run this in your Supabase SQL Editor

-- Step 1: Add new columns if they don't exist
DO $$ 
BEGIN
    -- Add student_number column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'attendance' AND column_name = 'student_number'
    ) THEN
        ALTER TABLE attendance ADD COLUMN student_number TEXT;
    END IF;

    -- Add last_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'attendance' AND column_name = 'last_name'
    ) THEN
        ALTER TABLE attendance ADD COLUMN last_name TEXT;
    END IF;

    -- Add first_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'attendance' AND column_name = 'first_name'
    ) THEN
        ALTER TABLE attendance ADD COLUMN first_name TEXT;
    END IF;

    -- Add program column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'attendance' AND column_name = 'program'
    ) THEN
        ALTER TABLE attendance ADD COLUMN program TEXT;
    END IF;

    -- Add year_level column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'attendance' AND column_name = 'year_level'
    ) THEN
        ALTER TABLE attendance ADD COLUMN year_level INTEGER;
    END IF;
END $$;

-- Step 2: Remove user_id column if it exists
DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'attendance' AND column_name = 'user_id'
    ) THEN
        -- First, drop any foreign key constraints on user_id
        ALTER TABLE attendance DROP CONSTRAINT IF EXISTS attendance_user_id_fkey;
        
        -- Then drop the column
        ALTER TABLE attendance DROP COLUMN user_id;
        
        RAISE NOTICE 'Removed user_id column from attendance table';
    END IF;
END $$;

-- Step 3: Add unique constraint if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'attendance_event_student_unique' 
        AND table_name = 'attendance'
    ) THEN
        ALTER TABLE attendance 
        ADD CONSTRAINT attendance_event_student_unique 
        UNIQUE (event_id, student_number);
        
        RAISE NOTICE 'Added unique constraint on (event_id, student_number)';
    END IF;
END $$;

-- Step 4: Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_attendance_event_id ON attendance(event_id);
CREATE INDEX IF NOT EXISTS idx_attendance_student_number ON attendance(student_number);
CREATE INDEX IF NOT EXISTS idx_attendance_deleted ON attendance(deleted);

-- Step 5: Ensure RLS is enabled
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

-- Step 6: Create RLS policies if they don't exist
DO $$ 
BEGIN
    -- Drop existing policies if they exist (to recreate them)
    DROP POLICY IF EXISTS "Attendance is viewable by everyone" ON attendance;
    DROP POLICY IF EXISTS "Attendance can be created by anyone" ON attendance;
    DROP POLICY IF EXISTS "Attendance can be updated by anyone" ON attendance;
    
    -- Create new policies
    CREATE POLICY "Attendance is viewable by everyone" ON attendance
        FOR SELECT USING (true);
    
    CREATE POLICY "Attendance can be created by anyone" ON attendance
        FOR INSERT WITH CHECK (true);
    
    CREATE POLICY "Attendance can be updated by anyone" ON attendance
        FOR UPDATE USING (true);
END $$;

-- Step 7: Ensure trigger exists for updated_at
DO $$ 
BEGIN
    -- Drop trigger if it exists
    DROP TRIGGER IF EXISTS update_attendance_updated_at ON attendance;
    
    -- Create trigger
    CREATE TRIGGER update_attendance_updated_at 
    BEFORE UPDATE ON attendance
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
END $$;

-- Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'attendance' 
ORDER BY ordinal_position;

-- Show constraints
SELECT 
    constraint_name, 
    constraint_type 
FROM information_schema.table_constraints 
WHERE table_name = 'attendance';
