import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/local/repositories/event_repository.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/core/models/permission.dart';
import 'package:uuid/uuid.dart';
import 'package:matcher/matcher.dart' as matcher;

/// Integration tests for synchronization
/// Task 15.5: Test synchronization
/// - Create event offline
/// - Sync when online
/// - Verify data in Supabase
/// - Test conflict resolution
///
/// NOTE: These tests verify local database behavior and sync flags.
/// Actual Supabase synchronization requires network connectivity and
/// is tested separately in integration tests with real Supabase instance.
void main() {
  late AppDatabase db;
  late UserSession userSession;
  late EventRepository eventRepo;
  late PermissionRepository permissionRepo;

  setUp(() {
    // Create in-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());
    userSession = UserSession();
    eventRepo = EventRepository(db, userSession);
    permissionRepo = PermissionRepository(db, userSession);
  });

  tearDown(() async {
    await db.close();
  });

  group('Synchronization Integration Tests', () {
    test('Create event offline - verify local storage and sync flag', () async {
      // Setup: Create user and organization
      final userId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test User',
              email: 'user@test.com',
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

      // Login
      userSession.setCurrentUser(
        userId: userId,
        email: 'user@test.com',
        name: 'Test User',
        role: 'member',
      );

      // Step 1: Create event "offline" (without remote repository)
      final result = await eventRepo.createEvent(
        orgId: orgId,
        name: 'Offline Event',
        eventDate: DateTime.now().add(const Duration(days: 7)),
        location: 'Test Location',
        description: 'Created while offline',
      );

      expect(result.success, true);
      final eventId = result.data!;

      // Step 2: Verify event is stored locally
      final event = await (db.select(db.events)
            ..where((e) => e.id.equals(eventId)))
          .getSingle();

      expect(event.id, eventId);
      expect(event.name, 'Offline Event');
      expect(event.orgId, orgId);
      expect(event.createdBy, userId);
      expect(event.description, 'Created while offline');

      // Step 3: Verify sync flag is set to false (needs sync)
      expect(event.isSynced, false,
        reason: 'Event created offline should be marked as not synced');

      // Step 4: Verify event is queryable
      final upcomingEvents = await eventRepo.watchUpcomingEvents(orgId).first;
      expect(upcomingEvents.length, 1);
      expect(upcomingEvents[0].name, 'Offline Event');
    });

    test('Permission changes offline - verify local storage and sync flag', () async {
      // Setup: Create organization
      final orgId = const Uuid().v4();

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Org',
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);

      // Step 1: Modify permissions "offline"
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
        Permission.editEvents.key: true,
      });

      // Step 2: Verify permissions are stored locally
      final permissions = await permissionRepo.getOfficerPermissions(orgId);
      final createEvents = permissions.firstWhere((p) => p.key == Permission.createEvents.key);
      final editEvents = permissions.firstWhere((p) => p.key == Permission.editEvents.key);

      expect(createEvents.isGranted, true);
      expect(editEvents.isGranted, true);

      // Step 3: Verify sync flags in database
      final dbPermissions = await (db.select(db.organizationPermissions)
            ..where((p) => p.orgId.equals(orgId)))
          .get();

      for (final perm in dbPermissions) {
        expect(perm.isSynced, false,
          reason: 'Permissions modified offline should be marked as not synced');
      }
    });

    test('Multiple offline changes accumulate for sync', () async {
      // Setup: Create user and organization
      final userId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test User',
              email: 'user@test.com',
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

      userSession.setCurrentUser(
        userId: userId,
        email: 'user@test.com',
        name: 'Test User',
        role: 'member',
      );

      // Create multiple events offline
      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Event 1',
        eventDate: DateTime.now().add(const Duration(days: 1)),
        location: 'Location 1',
      );

      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Event 2',
        eventDate: DateTime.now().add(const Duration(days: 2)),
        location: 'Location 2',
      );

      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Event 3',
        eventDate: DateTime.now().add(const Duration(days: 3)),
        location: 'Location 3',
      );

      // Verify all events are marked as not synced
      final unsyncedEvents = await (db.select(db.events)
            ..where((e) => e.orgId.equals(orgId) & e.isSynced.equals(false)))
          .get();

      expect(unsyncedEvents.length, 3,
        reason: 'All offline events should be marked for sync');
    });

    test('Verify clientUpdatedAt timestamp for conflict resolution', () async {
      // Setup: Create organization
      final orgId = const Uuid().v4();

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Org',
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);

      final timestamp1 = DateTime.now();

      // Wait a moment to ensure different timestamp
      await Future.delayed(const Duration(milliseconds: 10));

      // Modify permissions
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
      });

      final timestamp2 = DateTime.now();

      // Verify clientUpdatedAt is set and within expected range
      final permissions = await (db.select(db.organizationPermissions)
            ..where((p) => p.orgId.equals(orgId)))
          .get();

      for (final perm in permissions) {
        expect(perm.clientUpdatedAt, matcher.isNotNull,
          reason: 'clientUpdatedAt should be set');
        expect(perm.clientUpdatedAt!.isAfter(timestamp1), true,
          reason: 'clientUpdatedAt should be after operation start');
        expect(perm.clientUpdatedAt!.isBefore(timestamp2) || 
               perm.clientUpdatedAt!.isAtSameMomentAs(timestamp2), true,
          reason: 'clientUpdatedAt should be before or at operation end');
      }
    });

    test('Deleted flag for soft deletes', () async {
      // Setup: Create user and organization
      final userId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test User',
              email: 'user@test.com',
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

      userSession.setCurrentUser(
        userId: userId,
        email: 'user@test.com',
        name: 'Test User',
        role: 'member',
      );

      // Create event
      final result = await eventRepo.createEvent(
        orgId: orgId,
        name: 'Test Event',
        eventDate: DateTime.now().add(const Duration(days: 7)),
        location: 'Test Location',
      );

      final eventId = result.data!;

      // Delete event (soft delete)
      await eventRepo.deleteEvent(eventId);

      // Verify event still exists in database but marked as deleted
      final event = await (db.select(db.events)
            ..where((e) => e.id.equals(eventId)))
          .getSingle();

      expect(event.deleted, true,
        reason: 'Deleted event should be marked with deleted flag');

      // Verify event is not returned in queries
      final upcomingEvents = await eventRepo.watchUpcomingEvents(orgId).first;
      expect(upcomingEvents.length, 0,
        reason: 'Deleted events should not appear in queries');
    });

    test('Sync status tracking for batch operations', () async {
      // Setup: Create organization
      final orgId = const Uuid().v4();

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Org',
            ),
          );

      // Initialize permissions
      await permissionRepo.initializeDefaultPermissions(orgId);

      // Modify multiple permissions at once
      await permissionRepo.updateOfficerPermissions(orgId, {
        Permission.createEvents.key: true,
        Permission.editEvents.key: true,
        Permission.deleteEvents.key: true,
        Permission.manageMembers.key: true,
      });

      // Verify all modified permissions are marked for sync
      final modifiedPermissions = await (db.select(db.organizationPermissions)
            ..where((p) => 
                p.orgId.equals(orgId) & 
                p.enabledForOfficers.equals(true)))
          .get();

      expect(modifiedPermissions.length, 4);

      for (final perm in modifiedPermissions) {
        expect(perm.isSynced, false,
          reason: 'All permissions in batch update should be marked for sync');
      }
    });

    test('Query unsynced items for sync queue', () async {
      // Setup: Create user and organization
      final userId = const Uuid().v4();
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test User',
              email: 'user@test.com',
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

      userSession.setCurrentUser(
        userId: userId,
        email: 'user@test.com',
        name: 'Test User',
        role: 'member',
      );

      // Create some events
      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Event 1',
        eventDate: DateTime.now().add(const Duration(days: 1)),
        location: 'Location 1',
      );

      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Event 2',
        eventDate: DateTime.now().add(const Duration(days: 2)),
        location: 'Location 2',
      );

      // Query unsynced events (simulating sync queue)
      final unsyncedEvents = await (db.select(db.events)
            ..where((e) => e.isSynced.equals(false) & e.deleted.equals(false)))
          .get();

      expect(unsyncedEvents.length, 2,
        reason: 'Should be able to query all unsynced events for sync queue');

      // Simulate marking first event as synced
      await (db.update(db.events)
            ..where((e) => e.id.equals(unsyncedEvents[0].id)))
          .write(const EventsCompanion(
        isSynced: Value(true),
      ));

      // Query again
      final stillUnsynced = await (db.select(db.events)
            ..where((e) => e.isSynced.equals(false) & e.deleted.equals(false)))
          .get();

      expect(stillUnsynced.length, 1,
        reason: 'Only unsynced events should remain in queue');
    });
  });
}
