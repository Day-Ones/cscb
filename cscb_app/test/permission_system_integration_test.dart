import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';
import 'package:cscb_app/data/local/repositories/officer_title_repository.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/core/models/permission.dart';
import 'package:uuid/uuid.dart';

/// Integration tests for permission system
/// Task 15.2: Test permission system
/// - Test as president (all permissions)
/// - Test as officer (default permissions)
/// - Test as officer with overrides
/// - Test as regular member (no permissions)
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

  group('Permission System Integration Tests', () {
    test('President has all permissions', () async {
      // Setup: Create president user and organization
      final presidentId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: presidentId,
              name: 'Test President',
              email: 'president@test.com',
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
              userId: presidentId,
              orgId: orgId,
              role: 'president',
              status: const Value('approved'),
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);

      // Login as president
      userSession.setCurrentUser(
        userId: presidentId,
        email: 'president@test.com',
        name: 'Test President',
        role: 'member',
      );

      // Verify president has ALL permissions
      for (final permission in Permission.all) {
        final hasPermission = await permissionRepo.hasPermission(orgId, permission.key);
        expect(hasPermission, true, 
          reason: 'President should have ${permission.key} permission');
      }
    });

    test('Officer with default permissions (all disabled)', () async {
      // Setup: Create officer user and organization
      final officerId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();
      final officerTitleId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: officerId,
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
              id: officerTitleId,
              orgId: orgId,
              title: 'Vice President',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: officerId,
              orgId: orgId,
              role: 'member',
              status: const Value('approved'),
              officerTitleId: Value(officerTitleId),
            ),
          );

      // Initialize permissions (all disabled by default)
      await permissionRepo.initializeDefaultPermissions(orgId);

      // Login as officer
      userSession.setCurrentUser(
        userId: officerId,
        email: 'officer@test.com',
        name: 'Test Officer',
        role: 'member',
      );

      // Verify officer has NO permissions (all disabled by default)
      for (final permission in Permission.all) {
        final hasPermission = await permissionRepo.hasPermission(orgId, permission.key);
        expect(hasPermission, false, 
          reason: 'Officer should not have ${permission.key} permission when disabled');
      }
    });

    test('Officer with enabled default permissions', () async {
      // Setup: Create officer user and organization
      final officerId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();
      final officerTitleId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: officerId,
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
              id: officerTitleId,
              orgId: orgId,
              title: 'Vice President',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: officerId,
              orgId: orgId,
              role: 'member',
              status: const Value('approved'),
              officerTitleId: Value(officerTitleId),
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);

      // Enable some permissions for officers
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
        Permission.editEvents.key: true,
        Permission.viewAnalytics.key: true,
      });

      // Login as officer
      userSession.setCurrentUser(
        userId: officerId,
        email: 'officer@test.com',
        name: 'Test Officer',
        role: 'member',
      );

      // Verify officer has enabled permissions
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.editEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.viewAnalytics.key), true);

      // Verify officer does NOT have disabled permissions
      expect(await permissionRepo.hasPermission(orgId, Permission.manageMembers.key), false);
      expect(await permissionRepo.hasPermission(orgId, Permission.deleteEvents.key), false);
    });

    test('Officer with individual permission overrides', () async {
      // Setup: Create officer user and organization
      final officerId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();
      final officerTitleId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: officerId,
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
              id: officerTitleId,
              orgId: orgId,
              title: 'Vice President',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: officerId,
              orgId: orgId,
              role: 'member',
              status: const Value('approved'),
              officerTitleId: Value(officerTitleId),
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);

      // Enable create_events for all officers
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
      });

      // Login as officer
      userSession.setCurrentUser(
        userId: officerId,
        email: 'officer@test.com',
        name: 'Test Officer',
        role: 'member',
      );

      // Verify officer has create_events from default
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true);
      expect(await permissionRepo.hasPermission(orgId, Permission.manageMembers.key), false);

      // Add individual override: grant manage_members, revoke create_events
      await permissionRepo.updateMemberPermissions(membershipId, {
        Permission.manageMembers.key: true,
        Permission.createEvents.key: false,
      });

      // Verify overrides take precedence
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), false,
        reason: 'Individual override should revoke create_events');
      expect(await permissionRepo.hasPermission(orgId, Permission.manageMembers.key), true,
        reason: 'Individual override should grant manage_members');
    });

    test('Regular member has no permissions', () async {
      // Setup: Create regular member user and organization
      final memberId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: memberId,
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
              userId: memberId,
              orgId: orgId,
              role: 'member',
              status: const Value('approved'),
              // No officer title
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);

      // Enable some permissions for officers (should not affect regular members)
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
        Permission.viewAnalytics.key: true,
      });

      // Login as regular member
      userSession.setCurrentUser(
        userId: memberId,
        email: 'member@test.com',
        name: 'Test Member',
        role: 'member',
      );

      // Verify member has NO permissions
      for (final permission in Permission.all) {
        final hasPermission = await permissionRepo.hasPermission(orgId, permission.key);
        expect(hasPermission, false, 
          reason: 'Regular member should not have ${permission.key} permission');
      }
    });

    test('Regular member with individual permission grant', () async {
      // Setup: Create regular member user and organization
      final memberId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: memberId,
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
              userId: memberId,
              orgId: orgId,
              role: 'member',
              status: const Value('approved'),
              // No officer title
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);

      // Login as regular member
      userSession.setCurrentUser(
        userId: memberId,
        email: 'member@test.com',
        name: 'Test Member',
        role: 'member',
      );

      // Initially no permissions
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), false);

      // Grant individual permission to this specific member
      await permissionRepo.updateMemberPermissions(membershipId, {
        Permission.createEvents.key: true,
      });

      // Verify member now has the granted permission
      expect(await permissionRepo.hasPermission(orgId, Permission.createEvents.key), true,
        reason: 'Member should have create_events after individual grant');
      
      // But not other permissions
      expect(await permissionRepo.hasPermission(orgId, Permission.manageMembers.key), false);
    });

    test('Permission changes do not affect other organizations', () async {
      // Setup: Create two organizations
      final userId = const Uuid().v4();
      final org1Id = const Uuid().v4();
      final org2Id = const Uuid().v4();
      final membership1Id = const Uuid().v4();
      final membership2Id = const Uuid().v4();
      final officerTitle1Id = const Uuid().v4();
      final officerTitle2Id = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test User',
              email: 'user@test.com',
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
              id: officerTitle1Id,
              orgId: org1Id,
              title: 'Officer',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membership1Id,
              userId: userId,
              orgId: org1Id,
              role: 'member',
              status: const Value('approved'),
              officerTitleId: Value(officerTitle1Id),
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
              id: officerTitle2Id,
              orgId: org2Id,
              title: 'Officer',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membership2Id,
              userId: userId,
              orgId: org2Id,
              role: 'member',
              status: const Value('approved'),
              officerTitleId: Value(officerTitle2Id),
            ),
          );

      // Initialize permissions for both orgs
      await permissionRepo.initializeDefaultPermissions(org1Id);
      await permissionRepo.initializeDefaultPermissions(org2Id);

      // Login as user
      userSession.setCurrentUser(
        userId: userId,
        email: 'user@test.com',
        name: 'Test User',
        role: 'member',
      );

      // Enable permissions in Org 1 only
      await permissionRepo.updateOfficerPermissions(org1Id, {
        Permission.createEvents.key: true,
        Permission.manageMembers.key: true,
      });

      // Verify Org 1 has permissions
      expect(await permissionRepo.hasPermission(org1Id, Permission.createEvents.key), true);
      expect(await permissionRepo.hasPermission(org1Id, Permission.manageMembers.key), true);

      // Verify Org 2 does NOT have permissions (isolation)
      expect(await permissionRepo.hasPermission(org2Id, Permission.createEvents.key), false,
        reason: 'Org 2 should not be affected by Org 1 permission changes');
      expect(await permissionRepo.hasPermission(org2Id, Permission.manageMembers.key), false,
        reason: 'Org 2 should not be affected by Org 1 permission changes');
    });
  });
}
