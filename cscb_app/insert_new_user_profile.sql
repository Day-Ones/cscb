-- Insert New User Profile
-- Step 1: First, get the user ID you want to create a profile for
SELECT id, email, name FROM users;

-- Step 2: Insert the user profile (replace values as needed)
INSERT INTO user_profiles (
    id, 
    user_id, 
    name, 
    program, 
    year_level, 
    section, 
    is_synced, 
    client_updated_at,
    deleted, 
    created_at, 
    updated_at
)
VALUES (
    gen_random_uuid()::text,           -- Auto-generate ID
    'YOUR_USER_ID_HERE',               -- Replace with actual user ID from Step 1
    'John Doe',                        -- User's full name
    'BSIT',                            -- Program: BSIT, DIT, etc.
    1,                                 -- Year Level: 1, 2, 3, or 4
    1,                                 -- Section: 1, 2, 3, or 4
    true,                              -- is_synced
    NOW(),                             -- client_updated_at
    false,                             -- deleted
    NOW(),                             -- created_at
    NOW()                              -- updated_at
);

-- Examples for different programs and year levels:

-- BSIT 1st Year Section 1 (displays as "BSIT" and "1-1")
/*
INSERT INTO user_profiles (id, user_id, name, program, year_level, section, is_synced, client_updated_at, deleted, created_at, updated_at)
VALUES (gen_random_uuid()::text, 'user-id-1', 'John Doe', 'BSIT', 1, 1, true, NOW(), false, NOW(), NOW());
*/

-- BSIT 2nd Year Section 2 (displays as "BSIT" and "2-2")
/*
INSERT INTO user_profiles (id, user_id, name, program, year_level, section, is_synced, client_updated_at, deleted, created_at, updated_at)
VALUES (gen_random_uuid()::text, 'user-id-2', 'Jane Smith', 'BSIT', 2, 2, true, NOW(), false, NOW(), NOW());
*/

-- DIT 3rd Year Section 1 (displays as "DIT" and "3-1")
/*
INSERT INTO user_profiles (id, user_id, name, program, year_level, section, is_synced, client_updated_at, deleted, created_at, updated_at)
VALUES (gen_random_uuid()::text, 'user-id-3', 'Bob Johnson', 'DIT', 3, 1, true, NOW(), false, NOW(), NOW());
*/

-- BSIT 4th Year Section 1 (displays as "BSIT" and "4-1")
/*
INSERT INTO user_profiles (id, user_id, name, program, year_level, section, is_synced, client_updated_at, deleted, created_at, updated_at)
VALUES (gen_random_uuid()::text, 'user-id-4', 'Alice Brown', 'BSIT', 4, 1, true, NOW(), false, NOW(), NOW());
*/

-- Verify the insert
SELECT id, user_id, name, program, year_level, section FROM user_profiles;
