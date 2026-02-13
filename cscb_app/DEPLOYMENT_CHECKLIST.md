# Deployment Checklist

## ✅ Code Changes (Already Done)

- [x] Removed `user_id` from local Attendance table
- [x] Updated schema version to 7
- [x] Added migration logic
- [x] Removed `userId` from event repository
- [x] Added duplicate prevention in sync service
- [x] Added `getAttendanceByEventAndStudent()` method
- [x] Updated Supabase schema file
- [x] Created migration script
- [x] Added `connectivity_plus` package
- [x] Created `AutoSyncManager` for automatic sync
- [x] Registered `AutoSyncManager` in dependency injection
- [x] Started `AutoSyncManager` in main.dart
- [x] All files compile successfully

## 📋 Your Action Items

### 1. Update Supabase Database

- [ ] Go to https://bjsxjdgplvhuoxzgnlcs.supabase.co
- [ ] Click "SQL Editor"
- [ ] Click "New Query"
- [ ] Copy contents of `supabase_sync_migration.sql`
- [ ] Click "Run"
- [ ] Verify success message

### 2. Build and Test

- [ ] Run: `flutter pub get` (to install connectivity_plus)
- [ ] Run: `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] Run: `flutter run`
- [ ] Create a test event
- [ ] Scan a QR code
- [ ] Check Supabase Table Editor → attendance
- [ ] Verify record exists without `user_id` column
- [ ] Check console for "AutoSync" messages

### 3. Test Duplicate Prevention

- [ ] Scan same student on Device A
- [ ] Note the timestamp
- [ ] Scan same student on Device B (5 minutes later)
- [ ] Check Supabase - should only have 1 record
- [ ] Verify timestamp is from Device A (earlier)

### 4. Test Automatic Sync

- [ ] Turn off WiFi/mobile data
- [ ] Scan a QR code (data saved locally)
- [ ] Check console: "AutoSync: Offline - waiting for connection"
- [ ] Turn on WiFi/mobile data
- [ ] Check console: "AutoSync: Connection restored - triggering sync"
- [ ] Check Supabase - data should appear automatically
- [ ] No need to scan another QR code!

### 5. Verify Sync

- [ ] Check console logs for sync messages
- [ ] Look for: "AutoSync: ✅ All data synced successfully"
- [ ] Look for: "AutoSync: Connection restored - triggering sync"
- [ ] No error messages should appear

## 🎯 Expected Results

### In Supabase Table Editor

**attendance table columns:**
```
✅ id
✅ event_id
✅ student_number
✅ last_name
✅ first_name
✅ program
✅ year_level
✅ timestamp
✅ status
✅ is_synced
✅ client_updated_at
✅ deleted
✅ created_at
✅ updated_at
❌ user_id (should NOT exist)
```

**Constraints:**
```
✅ PRIMARY KEY (id)
✅ UNIQUE (event_id, student_number)
```

### In Console Logs

**Normal sync:**
```
✅ AutoSync: Online - triggering initial sync
✅ AutoSync: ✅ All data synced successfully
✅ AutoSync: Periodic sync triggered (every 5 minutes)
```

**Connection restored:**
```
✅ AutoSync: Connectivity changed - Online: true
✅ AutoSync: Connection restored - triggering sync
✅ AutoSync: ✅ All data synced successfully
```

**Duplicate detected:**
```
✅ "Updated Supabase with earlier attendance for [student_number]"
   OR
✅ "Kept earlier Supabase attendance for [student_number]"
```

## 📚 Documentation Reference

- `SYNC_FINAL_SUMMARY.md` - Overview of all changes
- `ATTENDANCE_SYNC_IMPROVEMENTS.md` - Detailed technical explanation
- `AUTO_SYNC_FEATURE.md` - Automatic sync documentation
- `SUPABASE_SYNC_QUICK_START.md` - Step-by-step setup guide
- `supabase_sync_migration.sql` - SQL to run in Supabase

## 🚨 Troubleshooting

### If migration fails:

1. Check if attendance table has data
2. Export data if needed: `SELECT * FROM attendance;`
3. Run migration again
4. Re-import data if necessary

### If sync fails:

1. Check console logs for errors
2. Verify Supabase credentials in `lib/core/config/supabase_config.dart`
3. Check RLS policies in Supabase
4. Verify internet connection

### If duplicates still occur:

1. Check if UNIQUE constraint exists:
   ```sql
   SELECT constraint_name, constraint_type 
   FROM information_schema.table_constraints 
   WHERE table_name = 'attendance';
   ```
2. Re-run migration if constraint missing

## ✨ Success Criteria

You'll know everything is working when:

1. ✅ App builds and runs without errors
2. ✅ Events sync to Supabase
3. ✅ Attendance syncs to Supabase
4. ✅ No `user_id` column in attendance table
5. ✅ Duplicate scans are prevented
6. ✅ Earlier timestamps are kept
7. ✅ Console shows "AutoSync" messages
8. ✅ Sync happens automatically when connection restored
9. ✅ No need to scan QR code to trigger sync
10. ✅ Periodic sync every 5 minutes when online

---

**Ready to deploy?** Start with Step 1: Update Supabase Database!
