import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';
import 'package:cscb_app/data/local/repositories/officer_title_repository.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/core/models/permission.dart';
import 'package:uuid/uuid.dart';

/// Integration tests for permission customization
/// Task 15.4: Test permission customization
/// - Modify default officer permissions in Org A
/// - Verify Org B unaffected
/// - Assign officer in Org A
/// - Verify custom permissions applied
void main() {
  late AppDatabase db;
  late UserSession userSession;
  late PermissionRepository permissionRepo;
  late OfficerTitleRepository officerTitleRepo;

  setUp(() {
    // Create in-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());
    userSession = UserSession();
    permissionRepo = PermissionRepository(db, userSession);
    officerTitleRepo = OfficerTitleRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Permission Customization Tests', () {
    test('Modify default officer permissions in Org A, verify Org B unaffected', () async {
      // Setup: Create two organizations
      final orgAId = const Uuid().v4();
      final orgBId = const Uuid().v4();

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgAId,
              name: 'Organization A',
            ),
          );

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgBId,
              name: 'Organization B',
            ),
          );

      // Initialize permissions for both organizations
      await permissionRepo.initializeDefaultPermissions(orgAId);
      await permissionRepo.initializeDefaultPermissions(orgBId);

      // Step 1: Verify both orgs start with same default permissions (all disabled)
      final orgAPermsBefore = await permissionRepo.getOfficerPermissions(orgAId);
      final orgBPermsBefore = await permissionRepo.getOfficerPermissions(orgBId);

      expect(orgAPermsBefore.length, Permission.all.length);
      expect(orgBPermsBefore.length, Permission.all.length);

      for (final perm in orgAPermsBefore) {
        expect(perm.isGranted, false, reason: 'All permissions should be disabled initially');
      }
      for (final perm in orgBPermsBefore) {
        expect(perm.isGranted, false, reason: 'All permissions should be disabled initially');
      }

      // Step 2: Modify default officer permissions in Org A
      await permissionRepo.updateOfficerPermissions(orgAId, {
        Permission.createEvents.key: true,
        Permission.editEvents.key: true,
        Permission.deleteEvents.key: true,
        Permission.viewAnalytics.key: true,
      });

      // Step 3: Verify Org A has updated permissions
      final orgAPermsAfter = await permissionRepo.getOfficerPermissions(orgAId);
      final createEventsA = orgAPermsAfter.firstWhere((p) => p.key == Permission.createEvents.key);
      final editEventsA = orgAPermsAfter.firstWhere((p) => p.key == Permission.editEvents.key);
      final deleteEventsA = orgAPermsAfter.firstWhere((p) => p.key == Permission.deleteEvents.key);
      final viewAnalyticsA = orgAPermsAfter.firstWhere((p) => p.key == Permission.viewAnalytics.key);
      final manageMembersA = orgAPermsAfter.firstWhere((p) => p.key == Permission.manageMembers.key);

      expect(createEventsA.isGranted, true);
      expect(editEventsA.isGranted, true);
      expect(deleteEventsA.isGranted, true);
      expect(viewAnalyticsA.isGranted, true);
      expect(manageMembersA.isGranted, false, reason: 'Unchanged permissions should remain disabled');

      // Step 4: Verify Org B is UNAFFECTED (isolation)
      final orgBPermsAfter = await permissionRepo.getOfficerPermissions(orgBId);
      
      for (final perm in orgBPermsAfter) {
        expect(perm.isGranted, false, 
          reason: 'Org B permissions should not be affected by Org A changes');
      }
    });

    test('Assign officer in Org A with custom permissions, verify they are applied', () async {
      // Setup: Create organization and member
      final userId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test Member',
              email: 'member@test.com',
              passwordHash: 'hash',
            ),
          );

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Org',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: userId,
              orgId: orgId,
              role: 'member',
              status: const Value('approved'),
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);

      // Step 1: Customize default officer permissions
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
        Permission.editEvents.key: true,
        Permission.viewAnalytics.key: true,
        // Leave others disabled
      });

      // Login as member
      userSession.setCurrentUser(
        userId: userId,
        email: 'member@test.com',
        name: 'Test Member',
        role: 'member',
      );

      // Step 2: Verify member has no permissions initially
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), false);
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), false);
      expect(await permissionRepo.hasPermission(orgId, Permission.viewAnalytics.key), false);

      // Step 3: Create and assign officer title
      final titleResult = await officerTitleRepo.createOfficerTitle(orgId, 'Vice President');
      final titleId = titleResult.data!;
      await officerTitleRepo.assignOfficerTitle(membershipId, titleId);

      // Step 4: Verify custom permissions are applied
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true,
        reason: 'Officer should have custom create_events permission');
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), true,
        reason: 'Officer should have custom edit_events permission');
      expect(await permissionRepo.hasPermission(orgId, Permission.viewAnalytics.key), true,
        reason: 'Officer should have custom view_analytics permission');

      // Verify disabled permissions are NOT granted
      expect(await permissionRepo.hasPermission(orgId, Permission.manageMembers.key), false,
        reason: 'Officer should not have disabled permissions');
      expect(await permissionRepo.hasPermission(orgId, Permission.deleteEvents.key), false,
        reason: 'Officer should not have disabled permissions');
    });

    test('Different organizations can have completely different permission sets', () async {
      // Setup: Create two organizations with officers
      final user1Id = const Uuid().v4();
      final user2Id = const Uuid().v4();
      final org1Id = const Uuid().v4();
      final org2Id = const Uuid().v4();
      final membership1Id = const Uuid().v4();
      final membership2Id = const Uuid().v4();
      final title1Id = const Uuid().v4();
      final title2Id = const Uuid().v4();

      // User 1
      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: user1Id,
              name: 'Officer 1',
              email: 'officer1@test.com',
              passwordHash: 'hash',
            ),
          );

      // User 2
      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: user2Id,
              name: 'Officer 2',
              email: 'officer2@test.com',
              passwordHash: 'hash',
            ),
          );

      // Organization 1
      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: org1Id,
              name: 'Org 1',
            ),
          );

      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: title1Id,
              orgId: org1Id,
              title: 'Officer',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membership1Id,
              userId: user1Id,
              orgId: org1Id,
              role: 'member',
              status: const Value('approved'),
              officerTitleId: Value(title1Id),
            ),
          );

      // Organization 2
      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: org2Id,
              name: 'Org 2',
            ),
          );

      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: title2Id,
              orgId: org2Id,
              title: 'Officer',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membership2Id,
              userId: user2Id,
              orgId: org2Id,
              role: 'member',
              status: const Value('approved'),
              officerTitleId: Value(title2Id),
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(org1Id);
      await permissionRepo.initializeDefaultPermissions(org2Id);

      // Customize Org 1: Enable event management permissions
      await permissionRepo.updateOfficerPermissions(org1Id, {
        Permission.createEvents.key: true,
        Permission.editEvents.key: true,
        Permission.deleteEvents.key: true,
      });

      // Customize Org 2: Enable member management permissions
      await permissionRepo.updateOfficerPermissions(org2Id, {
        Permission.manageMembers.key: true,
        Permission.assignOfficers.key: true,
        Permission.editOrganization.key: true,
      });

      // Test Officer 1 in Org 1
      userSession.setCurrentUser(
        userId: user1Id,
        email: 'officer1@test.com',
        name: 'Officer 1',
        role: 'member',
      );

      expect(await permissionRepo.hasPermission(org1Id, Permission.createEvents.key), true);
      expect(await permissionRepo.hasPermission(org1Id, Permission.editEvents.key), true);
      expect(await permissionRepo.hasPermission(org1Id, Permission.deleteEvents.key), true);
      expect(await permissionRepo.hasPermission(org1Id, Permission.manageMembers.key), false);
      expect(await permissionRepo.hasPermission(org1Id, Permission.assignOfficers.key), false);

      // Test Officer 2 in Org 2
      userSession.setCurrentUser(
        userId: user2Id,
        email: 'officer2@test.com',
        name: 'Officer 2',
        role: 'member',
      );

      expect(await permissionRepo.hasPermission(org2Id, Permission.manageMembers.key), true);
      expect(await permissionRepo.hasPermission(org2Id, Permission.assignOfficers.key), true);
      expect(await permissionRepo.hasPermission(org2Id, Permission.editOrganization.key), true);
      expect(await permissionRepo.hasPermission(org2Id, Permission.createEvents.key), false);
      expect(await permissionRepo.hasPermission(org2Id, Permission.editEvents.key), false);
    });

    test('Changing default permissions affects existing officers', () async {
      // Setup: Create organization with officer
      final userId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();
      final titleId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test Officer',
              email: 'officer@test.com',
              passwordHash: 'hash',
            ),
          );

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Org',
            ),
          );

      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: titleId,
              orgId: orgId,
              title: 'Vice President',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: userId,
              orgId: orgId,
              role: 'member',
              status: const Value('approved'),
              officerTitleId: Value(titleId),
            ),
          );

      // Initialize permissions and enable some
      await permissionRepo.initializeDefaultPermissions(orgId);
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
      });

      // Login as officer
      userSession.setCurrentUser(
        userId: userId,
        email: 'officer@test.com',
        name: 'Test Officer',
        role: 'member',
      );

      // Verify initial permissions
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), false);

      // Change default permissions
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: false, // Disable
        Permission.editEvents.key: true,    // Enable
        Permission.viewAnalytics.key: true, // Enable
      });

      // Verify permissions changed for existing officer
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), false,
        reason: 'Disabling default permission should affect existing officers');
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), true,
        reason: 'Enabling default permission should affect existing officers');
      expect(await permissionRepo.hasPermission(orgId, Permission.viewAnalytics.key), true,
        reason: 'Enabling default permission should affect existing officers');
    });

    test('Individual overrides persist through default permission changes', () async {
      // Setup: Create organization with officer
      final userId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();
      final titleId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test Officer',
              email: 'officer@test.com',
              passwordHash: 'hash',
            ),
          );

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Org',
            ),
          );

      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: titleId,
              orgId: orgId,
              title: 'Vice President',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: userId,
              orgId: orgId,
              role: 'member',
              status: const Value('approved'),
              officerTitleId: Value(titleId),
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
      });

      // Login as officer
      userSession.setCurrentUser(
        userId: userId,
        email: 'officer@test.com',
        name: 'Test Officer',
        role: 'member',
      );

      // Add individual override
      await permissionRepo.updateMemberPermissions(membershipId, {
        Permission.manageMembers.key: true, // Grant special permission
      });

      // Verify both default and override
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.manageMembers.key), true);

      // Change default permissions
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: false, // Disable default
        Permission.editEvents.key: true,    // Enable new default
      });

      // Verify default changed but override persists
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), false,
        reason: 'Default permission change should apply');
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), true,
        reason: 'New default permission should apply');
      expect(await permissionRepo.hasPermission(orgId, Permission.manageMembers.key), true,
        reason: 'Individual override should persist through default changes');
    });
  });
}
