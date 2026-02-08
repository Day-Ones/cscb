-- Sample User Profiles Data for Supabase
-- Run this script in your Supabase SQL Editor after creating users

-- Insert sample user profiles
-- Note: Replace the user_id values with actual user IDs from your users table

-- Example for admin user
INSERT INTO user_profiles (id, user_id, name, program, year_level, is_synced, deleted, created_at, updated_at)
VALUES 
  ('profile-1', 'user-id-1', 'John Doe', 'BSIT 1-1', '1st Year', true, false, NOW(), NOW()),
  ('profile-2', 'user-id-2', 'Jane Smith', 'DIT 2-1', '2nd Year', true, false, NOW(), NOW()),
  ('profile-3', 'user-id-3', 'Bob Johnson', 'BSIT 3-1', '3rd Year', true, false, NOW(), NOW());

-- To get actual user IDs, first run:
-- SELECT id, email, name FROM users;

-- Then update the user_id values above with the actual IDs from your users table

-- Example programs:
-- DIT 1-1, DIT 1-2, DIT 2-1, DIT 2-2, DIT 3-1, DIT 3-2
-- BSIT 1-1, BSIT 1-2, BSIT 2-1, BSIT 2-2, BSIT 3-1, BSIT 3-2, BSIT 4-1, BSIT 4-2

-- Example year levels:
-- 1st Year, 2nd Year, 3rd Year, 4th Year
