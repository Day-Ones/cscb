# Supabase Sync - Quick Start Guide

## Current Status ✅

Your app is already configured to sync events and attendance to Supabase! Here's what's been set up:

1. ✅ Supabase initialized in `main.dart`
2. ✅ Sync service implemented with event and attendance sync
3. ✅ Events automatically sync after creation
4. ✅ Attendance automatically syncs after QR code scan
5. ✅ Supabase credentials configured in `lib/core/config/supabase_config.dart`
6. ✅ Duplicate prevention - earlier attendance records are prioritized
7. ✅ Simplified schema - removed unnecessary user_id field

## What You Need to Do

### Step 1: Update Supabase Tables

Your Supabase database needs the attendance table updated to remove user_id and add duplicate prevention.

**Run the migration script:**
1. Go to your Supabase dashboard: https://bjsxjdgplvhuoxzgnlcs.supabase.co
2. Click on "SQL Editor" in the left sidebar
3. Click "New Query"
4. Copy and paste the contents of `supabase_sync_migration.sql`
5. Click "Run" to execute the migration

**What this does:**
- Removes the `user_id` column (not needed since there's no authentication)
- Adds a UNIQUE constraint on `(event_id, student_number)` to prevent duplicates
- Ensures earlier attendance records are kept when duplicates occur

### Step 2: Verify RLS Policies

The schema already includes RLS policies that allow anonymous access. Verify they're enabled:

1. Go to Supabase dashboard → Authentication → Policies
2. Check that these tables have policies:
   - `events` - Should have "Allow anonymous insert/select/update" policies
   - `attendance` - Should have "Allow anonymous insert/select/update" policies

If policies are missing, they're included in `supabase_schema.sql`.

### Step 3: Test the Sync

1. **Build and run the app:**
   ```bash
   flutter run
   ```

2. **Create a test event:**
   - Open the app
   - Tap "Create Event" (+ button)
   - Fill in event details
   - Save the event

3. **Check Supabase:**
   - Go to Supabase dashboard → Table Editor → events
   - You should see your event appear within a few seconds
   - Check the `is_synced` column - it should be `true`

4. **Record attendance:**
   - Open the event you created
   - Tap "Scan QR Code"
   - Scan a student QR code with this format:
     ```json
     {
       "studentNumber": "2023-00495-TG-0",
       "fullName": "Daniel Victorioso",
       "program": "Diploma in Information Technology",
       "yearLevel": "3rd Year"
     }
     ```

5. **Check attendance in Supabase:**
   - Go to Supabase dashboard → Table Editor → attendance
   - You should see the attendance record with:
     - student_number: "2023-00495-TG-0"
     - first_name: "Daniel"
     - last_name: "Victorioso"
     - program: "DIT 3-1"
     - year_level: 3
   - Note: No `user_id` field (it's been removed!)

6. **Test duplicate prevention:**
   - Scan the same student's QR code again
   - Local app will show "already checked in"
   - If scanned on another device, the earlier timestamp will be kept in Supabase

## How It Works

### Background Sync
- Sync happens automatically in the background
- Doesn't block the UI or slow down the app
- Local data is saved first, then synced to Supabase

### Duplicate Prevention
- If the same student is scanned multiple times on different devices
- The sync service checks for existing attendance in Supabase
- The EARLIER timestamp is always kept (first scan wins)
- Database has UNIQUE constraint as backup protection

### Offline Support
- App works completely offline
- Data is stored locally in SQLite
- When internet is available, data syncs automatically

### No Login Required
- Uses Supabase anonymous key
- No user authentication needed
- Simple and straightforward
- No user_id field needed in attendance

## Troubleshooting

### Events not appearing in Supabase?

1. **Check console logs:**
   - Run the app with `flutter run`
   - Look for error messages starting with "Failed to sync event"

2. **Verify Supabase credentials:**
   - Open `lib/core/config/supabase_config.dart`
   - Make sure URL and anon key are correct

3. **Check RLS policies:**
   - Go to Supabase dashboard → Authentication → Policies
   - Make sure anonymous users can insert/select/update

### Attendance not syncing?

1. **Check if attendance table has required columns:**
   - Go to Supabase dashboard → Table Editor → attendance
   - Verify these columns exist:
     - student_number
     - last_name
     - first_name
     - program
     - year_level
   - Verify `user_id` column does NOT exist (it's been removed)

2. **Run the migration:**
   - If columns are wrong, run `supabase_sync_migration.sql`

3. **Check for duplicate constraint errors:**
   - This is normal! It means duplicate prevention is working
   - The sync service handles this automatically

### App crashes on startup?

1. **Check Supabase initialization:**
   - Make sure `supabase_schema.sql` has been run
   - Verify all tables exist in Supabase

2. **Check internet connection:**
   - Supabase needs internet to initialize
   - App will work offline after first successful initialization

## Monitoring Sync Status

### In the App
- Events and attendance are marked as `isSynced: true` after successful sync
- Check local SQLite database to see sync status

### In Supabase
- Go to Table Editor → events or attendance
- Check the `is_synced` column
- Check the `client_updated_at` timestamp

## Next Steps

Once sync is working:

1. ✅ Events automatically backup to cloud
2. ✅ Attendance records automatically backup to cloud
3. ✅ Multiple devices can share data via Supabase
4. ✅ Data is safe even if device is lost

## Files Reference

- `supabase_schema.sql` - Full database schema with all tables
- `supabase_sync_migration.sql` - Migration to update attendance table (removes user_id, adds unique constraint)
- `SUPABASE_SYNC_SETUP.md` - Detailed technical documentation
- `ATTENDANCE_SYNC_IMPROVEMENTS.md` - Details on duplicate prevention and schema changes
- `lib/data/sync/sync_service.dart` - Sync implementation with duplicate prevention
- `lib/core/config/supabase_config.dart` - Supabase credentials

---

**Need Help?** Check the console logs when running the app with `flutter run` to see detailed sync status and error messages.
