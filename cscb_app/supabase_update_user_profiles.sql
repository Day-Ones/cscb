-- Migration: Update User Profiles Table Structure
-- This script updates the user_profiles table to use separate columns for program, year_level, and section

-- Step 1: Drop the existing user_profiles table (if you have important data, backup first!)
DROP TABLE IF EXISTS user_profiles CASCADE;

-- Step 2: Create the new user_profiles table with updated structure
CREATE TABLE user_profiles (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    program TEXT NOT NULL,              -- Only program name: BSIT, DIT, etc.
    year_level INTEGER NOT NULL,        -- Year as number: 1, 2, 3, 4
    section INTEGER NOT NULL,           -- Section as number: 1, 2, 3, 4
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 3: Create indexes for better query performance
CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
CREATE INDEX idx_user_profiles_deleted ON user_profiles(deleted);

-- Step 4: Enable Row Level Security (RLS)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Step 5: Create RLS Policies
CREATE POLICY "User profiles are viewable by everyone" ON user_profiles
    FOR SELECT USING (true);

CREATE POLICY "User profiles can be created by anyone" ON user_profiles
    FOR INSERT WITH CHECK (true);

CREATE POLICY "User profiles can be updated by anyone" ON user_profiles
    FOR UPDATE USING (true);

-- Step 6: Create trigger to automatically update updated_at
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Step 7: Insert sample data (update with your actual user IDs)
-- First, get your user IDs by running: SELECT id, email, name FROM users;

-- Example inserts (replace 'user-id-here' with actual user IDs):
/*
INSERT INTO user_profiles (id, user_id, name, program, year_level, section, is_synced, deleted, created_at, updated_at)
VALUES 
  (gen_random_uuid()::text, 'user-id-1', 'John Doe', 'BSIT', 1, 1, true, false, NOW(), NOW()),
  (gen_random_uuid()::text, 'user-id-2', 'Jane Smith', 'DIT', 2, 1, true, false, NOW(), NOW()),
  (gen_random_uuid()::text, 'user-id-3', 'Bob Johnson', 'BSIT', 3, 1, true, false, NOW(), NOW());
*/

-- Program options: BSIT, DIT
-- Year Level: 1, 2, 3, 4 (representing 1st, 2nd, 3rd, 4th year)
-- Section: 1, 2, 3, 4 (representing section 1, 2, 3, 4)
-- Display format will be: program + " " + year_level + "-" + section
-- Example: "BSIT 1-1", "DIT 2-1", "BSIT 3-2"
