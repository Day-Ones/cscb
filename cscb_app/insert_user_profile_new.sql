-- Insert User Profile with New Structure
-- Step 1: Get your user ID
-- Run this query first:
SELECT id, email, name FROM users WHERE email = 'johndoe@gmail.com';

-- Step 2: Insert the profile (replace 'YOUR_USER_ID_HERE' with the ID from Step 1)
INSERT INTO user_profiles (id, user_id, name, program, year_level, section, is_synced, deleted, created_at, updated_at)
VALUES (
  gen_random_uuid()::text,
  'YOUR_USER_ID_HERE',  -- Replace with actual user ID
  'John Doe',           -- Name
  'BSIT',              -- Program: BSIT, DIT, etc.
  1,                   -- Year Level: 1, 2, 3, or 4
  1,                   -- Section: 1, 2, 3, or 4
  true,
  false,
  NOW(),
  NOW()
);

-- This will display as: "BSIT" for program and "1-1" for Year Level & Section

-- More examples:
/*
-- BSIT 2nd Year Section 1 (displays as "BSIT" and "2-1")
INSERT INTO user_profiles (id, user_id, name, program, year_level, section, is_synced, deleted, created_at, updated_at)
VALUES (gen_random_uuid()::text, 'user-id-2', 'Jane Smith', 'BSIT', 2, 1, true, false, NOW(), NOW());

-- DIT 3rd Year Section 2 (displays as "DIT" and "3-2")
INSERT INTO user_profiles (id, user_id, name, program, year_level, section, is_synced, deleted, created_at, updated_at)
VALUES (gen_random_uuid()::text, 'user-id-3', 'Bob Johnson', 'DIT', 3, 2, true, false, NOW(), NOW());

-- BSIT 4th Year Section 1 (displays as "BSIT" and "4-1")
INSERT INTO user_profiles (id, user_id, name, program, year_level, section, is_synced, deleted, created_at, updated_at)
VALUES (gen_random_uuid()::text, 'user-id-4', 'Alice Brown', 'BSIT', 4, 1, true, false, NOW(), NOW());
*/
