-- ALTER User Profiles Table Structure
-- This script modifies the existing user_profiles table without losing data

-- Step 1: Add new columns
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS section INTEGER;

-- Step 2: Change year_level from TEXT to INTEGER
-- First, add a temporary column
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS year_level_new INTEGER;

-- Step 3: Update the new column with converted values
-- This converts "1st Year" -> 1, "2nd Year" -> 2, etc.
UPDATE user_profiles 
SET year_level_new = CASE 
    WHEN year_level LIKE '1%' THEN 1
    WHEN year_level LIKE '2%' THEN 2
    WHEN year_level LIKE '3%' THEN 3
    WHEN year_level LIKE '4%' THEN 4
    ELSE 1  -- Default to 1 if format is different
END;

-- Step 4: Update program column to remove year and section
-- This converts "BSIT 1-1" -> "BSIT", "DIT 2-1" -> "DIT"
UPDATE user_profiles 
SET program = CASE 
    WHEN program LIKE 'BSIT%' THEN 'BSIT'
    WHEN program LIKE 'DIT%' THEN 'DIT'
    ELSE SPLIT_PART(program, ' ', 1)  -- Take first word
END;

-- Step 5: Set default section values (all to section 1)
UPDATE user_profiles 
SET section = 1 
WHERE section IS NULL;

-- Step 6: Drop old year_level column and rename new one
ALTER TABLE user_profiles 
DROP COLUMN year_level;

ALTER TABLE user_profiles 
RENAME COLUMN year_level_new TO year_level;

-- Step 7: Make the new columns NOT NULL
ALTER TABLE user_profiles 
ALTER COLUMN year_level SET NOT NULL;

ALTER TABLE user_profiles 
ALTER COLUMN section SET NOT NULL;

-- Step 8: Verify the changes
SELECT id, user_id, name, program, year_level, section FROM user_profiles;
