import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';
import 'package:cscb_app/data/local/repositories/officer_title_repository.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/core/models/permission.dart';
import 'package:uuid/uuid.dart';
import 'package:matcher/matcher.dart' as matcher;

/// Integration tests for officer title assignment
/// Task 15.3: Test officer title assignment
/// - Assign officer title
/// - Verify permissions applied
/// - Remove officer title
/// - Verify permissions reverted
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

  group('Officer Title Assignment Tests', () {
    test('Assign officer title and verify permissions applied', () async {
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
              // No officer title initially
            ),
          );

      // Initialize permissions and enable some for officers
      await permissionRepo.initializeDefaultPermissions(orgId);
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
        Permission.editEvents.key: true,
        Permission.viewAnalytics.key: true,
      });

      // Login as member
      userSession.setCurrentUser(
        userId: userId,
        email: 'member@test.com',
        name: 'Test Member',
        role: 'member',
      );

      // Step 1: Verify member has NO permissions initially
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), false,
        reason: 'Regular member should not have permissions');
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), false);
      expect(await permissionRepo.hasPermission(orgId, Permission.viewAnalytics.key), false);

      // Step 2: Create officer title
      final titleResult = await officerTitleRepo.createOfficerTitle(orgId, 'Vice President');
      expect(titleResult.success, true);
      final titleId = titleResult.data!;

      // Step 3: Assign officer title to member
      final assignResult = await officerTitleRepo.assignOfficerTitle(membershipId, titleId);
      expect(assignResult.success, true);

      // Step 4: Verify membership has officer title
      final membership = await (db.select(db.memberships)
            ..where((m) => m.id.equals(membershipId)))
          .getSingle();
      expect(membership.officerTitleId, titleId);

      // Step 5: Verify member now has officer permissions
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true,
        reason: 'Officer should have create_events permission');
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), true,
        reason: 'Officer should have edit_events permission');
      expect(await permissionRepo.hasPermission(orgId, Permission.viewAnalytics.key), true,
        reason: 'Officer should have view_analytics permission');

      // Verify member does NOT have disabled permissions
      expect(await permissionRepo.hasPermission(orgId, Permission.manageMembers.key), false,
        reason: 'Officer should not have disabled permissions');
    });

    test('Remove officer title and verify permissions reverted', () async {
      // Setup: Create organization and officer
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
              officerTitleId: Value(titleId), // Already has officer title
            ),
          );

      // Initialize permissions and enable some for officers
      await permissionRepo.initializeDefaultPermissions(orgId);
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
        Permission.editEvents.key: true,
        Permission.viewAnalytics.key: true,
      });

      // Login as officer
      userSession.setCurrentUser(
        userId: userId,
        email: 'officer@test.com',
        name: 'Test Officer',
        role: 'member',
      );

      // Step 1: Verify officer has permissions
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.viewAnalytics.key), true);

      // Step 2: Remove officer title
      final removeResult = await officerTitleRepo.removeOfficerTitle(membershipId);
      expect(removeResult.success, true);

      // Step 3: Verify membership no longer has officer title
      final membership = await (db.select(db.memberships)
            ..where((m) => m.id.equals(membershipId)))
          .getSingle();
      expect(membership.officerTitleId, matcher.isNull,
        reason: 'Officer title should be removed');

      // Step 4: Verify member no longer has officer permissions
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), false,
        reason: 'Permissions should be reverted after removing officer title');
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), false,
        reason: 'Permissions should be reverted after removing officer title');
      expect(await permissionRepo.hasPermission(orgId, Permission.viewAnalytics.key), false,
        reason: 'Permissions should be reverted after removing officer title');
    });

    test('Officer with individual overrides retains overrides after title removal', () async {
      // Setup: Create organization and officer
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

      // Initialize permissions and enable some for officers
      await permissionRepo.initializeDefaultPermissions(orgId);
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
        Permission.editEvents.key: true,
      });

      // Login as officer
      userSession.setCurrentUser(
        userId: userId,
        email: 'officer@test.com',
        name: 'Test Officer',
        role: 'member',
      );

      // Add individual permission override
      await permissionRepo.updateMemberPermissions(membershipId, {
        Permission.manageMembers.key: true, // Grant special permission
      });

      // Verify officer has both default and override permissions
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.manageMembers.key), true);

      // Remove officer title
      await officerTitleRepo.removeOfficerTitle(membershipId);

      // Verify default permissions are gone
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), false);
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), false);

      // But individual override should remain
      expect(await permissionRepo.hasPermission(orgId, Permission.manageMembers.key), true,
        reason: 'Individual permission overrides should persist after title removal');
    });

    test('Reassign different officer title', () async {
      // Setup: Create organization and member
      final userId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();
      final title1Id = const Uuid().v4();
      final title2Id = const Uuid().v4();

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

      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: title1Id,
              orgId: orgId,
              title: 'Vice President',
            ),
          );

      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: title2Id,
              orgId: orgId,
              title: 'Secretary',
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
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
      });

      // Login as member
      userSession.setCurrentUser(
        userId: userId,
        email: 'member@test.com',
        name: 'Test Member',
        role: 'member',
      );

      // Assign first title
      await officerTitleRepo.assignOfficerTitle(membershipId, title1Id);
      
      var membership = await (db.select(db.memberships)
            ..where((m) => m.id.equals(membershipId)))
          .getSingle();
      expect(membership.officerTitleId, title1Id);
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true);

      // Reassign to second title
      await officerTitleRepo.assignOfficerTitle(membershipId, title2Id);
      
      membership = await (db.select(db.memberships)
            ..where((m) => m.id.equals(membershipId)))
          .getSingle();
      expect(membership.officerTitleId, title2Id,
        reason: 'Should update to new officer title');
      
      // Permissions should still apply (same default permissions)
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true);
    });

    test('Multiple officers with same title all get permissions', () async {
      // Setup: Create organization and two members
      final user1Id = const Uuid().v4();
      final user2Id = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membership1Id = const Uuid().v4();
      final membership2Id = const Uuid().v4();
      final titleId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: user1Id,
              name: 'Member 1',
              email: 'member1@test.com',
              passwordHash: 'hash',
            ),
          );

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: user2Id,
              name: 'Member 2',
              email: 'member2@test.com',
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
              id: membership1Id,
              userId: user1Id,
              orgId: orgId,
              role: 'member',
              status: const Value('approved'),
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membership2Id,
              userId: user2Id,
              orgId: orgId,
              role: 'member',
              status: const Value('approved'),
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
        Permission.viewAnalytics.key: true,
      });

      // Assign same title to both members
      await officerTitleRepo.assignOfficerTitle(membership1Id, titleId);
      await officerTitleRepo.assignOfficerTitle(membership2Id, titleId);

      // Test as first officer
      userSession.setCurrentUser(
        userId: user1Id,
        email: 'member1@test.com',
        name: 'Member 1',
        role: 'member',
      );

      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.viewAnalytics.key), true);

      // Test as second officer
      userSession.setCurrentUser(
        userId: user2Id,
        email: 'member2@test.com',
        name: 'Member 2',
        role: 'member',
      );

      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.viewAnalytics.key), true);
    });
  });
}
