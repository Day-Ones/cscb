# Profile Feature Documentation

## Overview
The profile page displays user information including name, program, year level, app version, and provides access to FAQs.

## Database Schema

### User Profiles Table
The `user_profiles` table stores additional user information:

```sql
CREATE TABLE user_profiles (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    program TEXT NOT NULL,
    year_level TEXT NOT NULL,
    is_synced BOOLEAN DEFAULT FALSE,
    client_updated_at TIMESTAMP WITH TIME ZONE,
    deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## Features

### 1. User Information Display
- **Name**: Displays the user's full name from the user_profile table
- **Email**: Shows the user's email address
- **Program**: Shows the academic program (e.g., DIT 1-1, BSIT 2-1)
- **Year Level**: Displays the student's year level (e.g., 1st Year, 2nd Year)
- **App Version**: Shows the current app version from package info

### 2. FAQ Section
Accessible via:
- FAQ button in the app bar (top right)
- FAQ button in the profile page body

The FAQ includes answers to common questions about:
- Updating profile information
- Joining organizations
- User roles
- Event attendance
- Password reset
- Signing out
- Offline mode

### 3. Logout Functionality
Users can sign out of the app using the logout button at the bottom of the profile page.

## Setup Instructions

### 1. Database Migration
The local database will automatically migrate to include the `user_profiles` table when you run the app.

### 2. Supabase Setup
Run the updated `supabase_schema.sql` in your Supabase SQL Editor to create the `user_profiles` table.

### 3. Seed User Profiles
Use the `seed_user_profiles.sql` script to add sample user profile data:

1. First, get the user IDs from your users table:
   ```sql
   SELECT id, email, name FROM users;
   ```

2. Update the `seed_user_profiles.sql` script with actual user IDs

3. Run the script in Supabase SQL Editor

## Program Format Examples
- **DIT Programs**: DIT 1-1, DIT 1-2, DIT 2-1, DIT 2-2, DIT 3-1, DIT 3-2
- **BSIT Programs**: BSIT 1-1, BSIT 1-2, BSIT 2-1, BSIT 2-2, BSIT 3-1, BSIT 3-2, BSIT 4-1, BSIT 4-2

## Year Level Format
- 1st Year
- 2nd Year
- 3rd Year
- 4th Year

## Code Structure

### Files Modified/Created
1. `lib/data/local/db/app_database.dart` - Added UserProfiles table
2. `lib/data/local/repositories/user_profile_repository.dart` - New repository for user profiles
3. `lib/screens/profile_page.dart` - Updated profile page with new features
4. `lib/core/di/locator.dart` - Added UserProfileRepository to DI
5. `supabase_schema.sql` - Added user_profiles table schema
6. `seed_user_profiles.sql` - Sample data for user profiles

### Dependencies Added
- `package_info_plus: ^8.0.0` - For retrieving app version information

## Usage

### Accessing User Profile Data
```dart
final profileRepo = getIt<UserProfileRepository>();
final profile = await profileRepo.getUserProfileByUserId(userId);

if (profile != null) {
  print('Name: ${profile.name}');
  print('Program: ${profile.program}');
  print('Year Level: ${profile.yearLevel}');
}
```

### Creating a User Profile
```dart
final newProfile = UserProfilesCompanion(
  id: Value('profile-id'),
  userId: Value('user-id'),
  name: Value('John Doe'),
  program: Value('BSIT 1-1'),
  yearLevel: Value('1st Year'),
  isSynced: const Value(false),
  deleted: const Value(false),
);

await profileRepo.createUserProfile(newProfile);
```

## UI Components

### Profile Info Cards
Each piece of information is displayed in a clean card with:
- Icon (school, grade, phone)
- Label (Program, Year Level, App Version)
- Value (the actual data)

### FAQ Modal
- Draggable bottom sheet
- Expandable FAQ items
- Clean, organized layout
- Easy to close

### Warning State
If a user doesn't have a profile set up, a warning message is displayed prompting them to contact an admin.

## Future Enhancements
- Allow users to edit their own profile information
- Add profile picture upload
- Display more statistics (attendance rate, events attended, etc.)
- Add more FAQ items based on user feedback
