-- Create User Profile for John Doe
-- First, find your user ID by running this query:
-- SELECT id, email, name FROM users WHERE email = 'johndoe@gmail.com';

-- Then replace 'YOUR_USER_ID_HERE' with the actual ID from the query above
-- and run this INSERT statement:

INSERT INTO user_profiles (id, user_id, name, program, year_level, is_synced, deleted, created_at, updated_at)
VALUES (
  gen_random_uuid()::text,  -- Generate a random UUID for the profile ID
  'YOUR_USER_ID_HERE',       -- Replace with actual user ID from the SELECT query above
  'John Doe',                -- Name
  'BSIT 1-1',               -- Program (e.g., BSIT 1-1, DIT 2-1, etc.)
  '1st Year',               -- Year Level
  true,                     -- is_synced
  false,                    -- deleted
  NOW(),                    -- created_at
  NOW()                     -- updated_at
);

-- Example for multiple users:
-- First get all user IDs:
-- SELECT id, email, name FROM users;

-- Then insert profiles for each user:
/*
INSERT INTO user_profiles (id, user_id, name, program, year_level, is_synced, deleted, created_at, updated_at)
VALUES 
  (gen_random_uuid()::text, 'user-id-1', 'John Doe', 'BSIT 1-1', '1st Year', true, false, NOW(), NOW()),
  (gen_random_uuid()::text, 'user-id-2', 'Jane Smith', 'DIT 2-1', '2nd Year', true, false, NOW(), NOW()),
  (gen_random_uuid()::text, 'user-id-3', 'Bob Johnson', 'BSIT 3-1', '3rd Year', true, false, NOW(), NOW());
*/

-- Available Program Options:
-- DIT: DIT 1-1, DIT 1-2, DIT 2-1, DIT 2-2, DIT 3-1, DIT 3-2
-- BSIT: BSIT 1-1, BSIT 1-2, BSIT 2-1, BSIT 2-2, BSIT 3-1, BSIT 3-2, BSIT 4-1, BSIT 4-2

-- Year Level Options:
-- 1st Year, 2nd Year, 3rd Year, 4th Year
