# Supabase Setup Guide for CSCB App

## Prerequisites
- A Supabase account (sign up at https://supabase.com)
- A Supabase project created

## Step 1: Get Your Supabase Credentials

1. Go to your Supabase project dashboard
2. Click on **Settings** (gear icon) in the left sidebar
3. Click on **API** under Project Settings
4. Copy the following:
   - **Project URL** (looks like: `https://xxxxxxxxxxxxx.supabase.co`)
   - **anon public** key (the long JWT token)

## Step 2: Configure the App

1. Open `lib/core/config/supabase_config.dart`
2. Replace the placeholder values with your actual credentials:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'your-anon-key-here';
}
```

## Step 3: Set Up Database Tables

1. Go to your Supabase project dashboard
2. Click on **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy the entire contents of `supabase_schema.sql` file
5. Paste it into the SQL editor
6. Click **Run** to execute the script

This will create:
- All necessary tables (users, organizations, memberships, events, attendance)
- Indexes for better performance
- Row Level Security (RLS) policies
- Automatic timestamp triggers

## Step 4: Verify Database Setup

1. Click on **Table Editor** in the left sidebar
2. You should see all 5 tables:
   - users
   - organizations
   - memberships
   - events
   - attendance

## Step 5: Test the Connection

1. Run the app: `flutter run`
2. The app will automatically:
   - Initialize Supabase connection
   - Create local database
   - Initialize super admin and test user locally

## Features

### Offline-First Architecture
- The app uses **Drift** for local SQLite database
- Data is stored locally first for offline functionality
- Supabase is used for cloud sync and backup

### Sync Strategy
- Local database is the primary data source
- Remote repositories are available for syncing data to Supabase
- You can implement sync logic as needed

### Available Remote Repositories

1. **RemoteUserRepository** (`lib/data/remote/repositories/remote_user_repository.dart`)
   - `getAllUsers()` - Fetch all users
   - `getUserByEmail(email)` - Get user by email
   - `createUser(user)` - Create new user
   - `updateUser(id, updates)` - Update user
   - `deleteUser(id)` - Soft delete user

2. **RemoteOrgRepository** (`lib/data/remote/repositories/remote_org_repository.dart`)
   - `getAllOrganizations()` - Fetch all organizations
   - `getOrganizationsByStatus(status)` - Get orgs by status
   - `createOrganization(org)` - Create new organization
   - `updateOrganization(id, updates)` - Update organization
   - `approveOrganization(id)` - Approve pending org
   - `suspendOrganization(id)` - Suspend active org
   - `deleteOrganization(id)` - Soft delete org

## Next Steps

### Implementing Sync Logic

You can implement sync in several ways:

1. **Manual Sync Button**: Add a sync button that uploads local changes to Supabase
2. **Automatic Sync**: Sync on app startup or when internet is available
3. **Real-time Sync**: Use Supabase Realtime to listen for changes

Example sync implementation:

```dart
// In your repository or service
Future<void> syncUsersToSupabase() async {
  final localUsers = await localUserRepository.getAllUsers();
  final remoteUserRepo = RemoteUserRepository();
  
  for (var user in localUsers) {
    if (!user.isSynced) {
      await remoteUserRepo.createUser({
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'password_hash': user.passwordHash,
        'role': user.role,
        'deleted': user.deleted,
      });
      
      // Mark as synced locally
      await localUserRepository.markAsSynced(user.id);
    }
  }
}
```

## Security Notes

1. **Password Hashing**: Passwords are hashed with bcrypt before storage
2. **RLS Policies**: Basic RLS policies are set up - customize them based on your needs
3. **API Keys**: Never commit your Supabase credentials to version control
4. **Consider**: Add `.env` file support for better credential management

## Troubleshooting

### Connection Issues
- Verify your Supabase URL and anon key are correct
- Check your internet connection
- Ensure Supabase project is active (not paused)

### Database Errors
- Verify all tables were created successfully
- Check RLS policies are enabled
- Review Supabase logs in the dashboard

### Sync Issues
- Check local database has data to sync
- Verify network connectivity
- Review error messages in console

## Support

For Supabase-specific issues, refer to:
- Supabase Documentation: https://supabase.com/docs
- Supabase Flutter SDK: https://supabase.com/docs/reference/dart/introduction
