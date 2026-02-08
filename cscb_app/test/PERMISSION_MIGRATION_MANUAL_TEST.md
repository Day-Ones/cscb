# Permission Migration Manual Test Guide

## Overview
This document provides manual testing steps to verify that the permission migration system works correctly for existing organizations.

## Requirements Tested
- **Requirement 6.1**: Initialize default permissions for all existing organizations
- **Requirement 7.4**: Verify presidents have all permissions

## Prerequisites
- App must be running on a device or emulator (not in test environment due to SQLite limitations)
- At least one organization should exist in the database before running the migration

## Test Scenarios

### Scenario 1: Initialize Permissions for Existing Organizations

**Steps:**
1. Create one or more organizations using the app (before the migration code is deployed)
2. Deploy the app with the migration code
3. Launch the app (migration runs automatically on startup)
4. Check the console logs for migration messages

**Expected Results:**
- Console should show: "Found X organizations to check for permissions"
- For each organization without permissions: "Initializing permissions for organization: [Name] ([ID])"
- For organizations that already have permissions: "Organization [Name] already has X permissions"
- Console should show: "Permission initialization complete"

**Verification:**
- Query the `organization_permissions` table in the database
- Each organization should have 8 permission entries (one for each permission type)
- All permissions should have `enabled_for_officers = false` initially

### Scenario 2: Verify Presidents Have All Permissions

**Steps:**
1. Login as a president of an organization
2. Navigate to the organization dashboard
3. Try to access all permission-protected features:
   - Create Event button should be visible
   - Manage Members button should be visible
   - Permission Settings should be accessible
   - Officer Title Management should be accessible

**Expected Results:**
- All buttons and features should be visible and accessible
- No "permission denied" errors should occur
- President can perform all actions regardless of default officer permissions

### Scenario 3: Verify Regular Members Have No Permissions

**Steps:**
1. Login as a regular member (not president, not officer)
2. Navigate to the organization dashboard
3. Check which features are visible

**Expected Results:**
- Create Event button should NOT be visible
- Manage Members button should NOT be visible
- Permission Settings should NOT be accessible
- Only view-only features should be available

### Scenario 4: Verify Officers Get Permissions When Enabled

**Steps:**
1. Login as president
2. Create an officer title (e.g., "Vice President")
3. Assign the officer title to a member
4. Go to Permission Settings
5. Enable "Create Events" permission for officers
6. Logout and login as the officer
7. Navigate to the organization dashboard

**Expected Results:**
- Officer should see the "Create Event" button
- Officer should be able to create events
- Officer should NOT see other permission-protected features (like Manage Members)

### Scenario 5: Verify No Duplicate Permissions

**Steps:**
1. Run the app multiple times (migration runs on each startup)
2. Query the `organization_permissions` table

**Expected Results:**
- Each organization should still have exactly 8 permission entries
- No duplicate permissions should be created
- Console should show: "Organization [Name] already has 8 permissions" on subsequent runs

## Database Queries for Verification

### Check Organization Permissions
```sql
SELECT * FROM organization_permissions WHERE org_id = '[ORG_ID]';
```
Expected: 8 rows, all with `enabled_for_officers = 0`

### Check All Organizations Have Permissions
```sql
SELECT 
  o.id,
  o.name,
  COUNT(op.id) as permission_count
FROM organizations o
LEFT JOIN organization_permissions op ON o.id = op.org_id
WHERE o.deleted = 0
GROUP BY o.id, o.name;
```
Expected: Each organization should have `permission_count = 8`

### Check President Membership
```sql
SELECT * FROM memberships 
WHERE org_id = '[ORG_ID]' 
AND role = 'president' 
AND status = 'approved';
```

## Troubleshooting

### Issue: Migration doesn't run
- Check console logs for errors
- Verify `PermissionMigrationService` is registered in `locator.dart`
- Verify migration is called in `main.dart`

### Issue: Permissions not working
- Check that user is logged in (`UserSession.isLoggedIn`)
- Verify membership status is 'approved'
- Check organization permissions in database

### Issue: Duplicate permissions created
- Check migration logic in `PermissionMigrationService`
- Verify the check for existing permissions is working correctly

## Success Criteria

All tests pass when:
1. ✅ All existing organizations have 8 permissions initialized
2. ✅ No duplicate permissions are created on multiple runs
3. ✅ Presidents can access all features
4. ✅ Regular members cannot access permission-protected features
5. ✅ Officers get permissions when enabled by president
6. ✅ Permission changes in one organization don't affect other organizations
