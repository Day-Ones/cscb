import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';
import 'package:cscb_app/data/local/services/permission_migration_service.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/core/models/permission.dart';
import 'package:uuid/uuid.dart';

/// Test permission migration for existing organizations
/// Requirements: 6.1, 7.4
void main() {
  late AppDatabase db;
  late UserSession userSession;
  late PermissionRepository permissionRepo;
  late PermissionMigrationService migrationService;

  setUp(() {
    // Create in-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());
    userSession = UserSession();
    permissionRepo = PermissionRepository(db, userSession);
    migrationService = PermissionMigrationService(db, permissionRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('Permission Migration Tests', () {
    test('should initialize permissions for existing organizations', () async {
      // Create test organizations without permissions
      final org1Id = const Uuid().v4();
      final org2Id = const Uuid().v4();

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: org1Id,
              name: 'Test Org 1',
            ),
          );

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: org2Id,
              name: 'Test Org 2',
            ),
          );

      // Verify no permissions exist yet
      final permsBefore = await db.select(db.organizationPermissions).get();
      expect(permsBefore.isEmpty, true);

      // Run migration
      await migrationService.initializePermissionsForExistingOrganizations();

      // Verify permissions were created for both organizations
      final permsAfter = await db.select(db.organizationPermissions).get();
      
      // Should have permissions for both orgs (8 permissions each)
      expect(permsAfter.length, Permission.all.length * 2);

      // Verify org1 has all permissions
      final org1Perms = permsAfter.where((p) => p.orgId == org1Id).toList();
      expect(org1Perms.length, Permission.all.length);
      
      // Verify all permissions are initially disabled
      for (final perm in org1Perms) {
        expect(perm.enabledForOfficers, false);
      }

      // Verify org2 has all permissions
      final org2Perms = permsAfter.where((p) => p.orgId == org2Id).toList();
      expect(org2Perms.length, Permission.all.length);
    });

    test('should not duplicate permissions for organizations that already have them', () async {
      // Create test organization
      final orgId = const Uuid().v4();

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Org',
            ),
          );

      // Initialize permissions once
      await permissionRepo.initializeDefaultPermissions(orgId);

      final permsAfterFirst = await db.select(db.organizationPermissions).get();
      expect(permsAfterFirst.length, Permission.all.length);

      // Run migration (should not create duplicates)
      await migrationService.initializePermissionsForExistingOrganizations();

      final permsAfterMigration = await db.select(db.organizationPermissions).get();
      expect(permsAfterMigration.length, Permission.all.length);
    });

    test('should verify presidents have all permissions', () async {
      // Create test user and organization
      final userId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
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
              userId: userId,
              orgId: orgId,
              role: 'president',
              status: const Value('approved'),
            ),
          );

      // Initialize permissions
      await migrationService.initializePermissionsForExistingOrganizations();

      // Login as president
      userSession.setCurrentUser(
        userId: userId,
        email: 'president@test.com',
        name: 'Test President',
        role: 'member',
      );

      // Verify president has all permissions
      for (final permission in Permission.all) {
        final hasPermission = await permissionRepo.hasPermission(orgId, permission.key);
        expect(hasPermission, true, reason: 'President should have ${permission.key} permission');
      }
    });

    test('should verify regular members have no permissions by default', () async {
      // Create test user and organization
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
      await migrationService.initializePermissionsForExistingOrganizations();

      // Login as member
      userSession.setCurrentUser(
        userId: userId,
        email: 'member@test.com',
        name: 'Test Member',
        role: 'member',
      );

      // Verify member has no permissions
      for (final permission in Permission.all) {
        final hasPermission = await permissionRepo.hasPermission(orgId, permission.key);
        expect(hasPermission, false, reason: 'Regular member should not have ${permission.key} permission');
      }
    });

    test('should verify officers get permissions when enabled', () async {
      // Create test user and organization
      final userId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();
      final officerTitleId = const Uuid().v4();

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
              id: officerTitleId,
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
              officerTitleId: Value(officerTitleId),
            ),
          );

      // Initialize permissions
      await migrationService.initializePermissionsForExistingOrganizations();

      // Login as officer
      userSession.setCurrentUser(
        userId: userId,
        email: 'officer@test.com',
        name: 'Test Officer',
        role: 'member',
      );

      // Initially, officer should have no permissions (all disabled by default)
      for (final permission in Permission.all) {
        final hasPermission = await permissionRepo.hasPermission(orgId, permission.key);
        expect(hasPermission, false, reason: 'Officer should not have ${permission.key} permission when disabled');
      }

      // Enable create_events permission for officers
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
      });

      // Now officer should have create_events permission
      final hasCreateEvents = await permissionRepo.hasPermission(orgId, Permission.createEvents.key);
      expect(hasCreateEvents, true, reason: 'Officer should have create_events permission when enabled');

      // But not other permissions
      final hasManageMembers = await permissionRepo.hasPermission(orgId, Permission.manageMembers.key);
      expect(hasManageMembers, false, reason: 'Officer should not have manage_members permission when disabled');
    });
  });
}
