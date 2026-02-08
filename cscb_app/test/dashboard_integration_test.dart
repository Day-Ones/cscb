import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/local/repositories/event_repository.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:uuid/uuid.dart';
import 'package:matcher/matcher.dart' as matcher;

/// Integration tests for complete dashboard flow
/// Task 15.1: Test complete dashboard flow
/// - View statistics
/// - View upcoming event
/// - Create event
/// - Navigate to event details
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

  group('Dashboard Flow Integration Tests', () {
    test('Complete dashboard flow: view statistics, upcoming event, create event', () async {
      // Setup: Create test user and organization
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
              name: 'Test Organization',
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
      await permissionRepo.initializeDefaultPermissions(orgId);

      // Login as president
      userSession.setCurrentUser(
        userId: userId,
        email: 'president@test.com',
        name: 'Test President',
        role: 'member',
      );

      // Step 1: View statistics - verify initial counts
      final initialUpcomingCount = await eventRepo.getUpcomingEventCount(orgId);
      final initialPastCount = await eventRepo.getPastEventCount(orgId);

      expect(initialUpcomingCount, 0, reason: 'Should have 0 upcoming events initially');
      expect(initialPastCount, 0, reason: 'Should have 0 past events initially');

      // Step 2: View upcoming event - should be null initially
      final initialNextEvent = await eventRepo.getNextUpcomingEvent(orgId);
      expect(initialNextEvent, matcher.isNull, reason: 'Should have no upcoming events initially');

      // Step 3: Create event
      final createResult = await eventRepo.createEvent(
        orgId: orgId,
        name: 'Annual General Meeting',
        eventDate: DateTime.now().add(const Duration(days: 7)),
        location: 'Room 301',
        description: 'Discuss annual plans and budget',
        maxAttendees: 50,
      );

      expect(createResult.success, true, reason: 'Event creation should succeed');
      expect(createResult.data, matcher.isNotNull, reason: 'Should return event ID');

      // Step 4: Verify statistics updated
      final updatedUpcomingCount = await eventRepo.getUpcomingEventCount(orgId);
      expect(updatedUpcomingCount, 1, reason: 'Should have 1 upcoming event after creation');

      // Step 5: View upcoming event - should now exist
      final nextEvent = await eventRepo.getNextUpcomingEvent(orgId);
      expect(nextEvent, matcher.isNotNull, reason: 'Should have upcoming event');
      expect(nextEvent!.name, 'Annual General Meeting');
      expect(nextEvent.location, 'Room 301');
      expect(nextEvent.description, 'Discuss annual plans and budget');
      expect(nextEvent.maxAttendees, 50);
      expect(nextEvent.isUpcoming, true);
      expect(nextEvent.isPast, false);

      // Step 6: Verify event details can be retrieved
      final eventId = createResult.data!;
      final eventQuery = await (db.select(db.events)
            ..where((e) => e.id.equals(eventId)))
          .getSingle();
      
      expect(eventQuery.id, eventId);
      expect(eventQuery.name, 'Annual General Meeting');
      expect(eventQuery.orgId, orgId);
      expect(eventQuery.createdBy, userId);
    });

    test('Dashboard shows multiple events correctly ordered', () async {
      // Setup
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

      // Create multiple events
      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Event in 7 days',
        eventDate: DateTime.now().add(const Duration(days: 7)),
        location: 'Location 1',
      );

      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Event in 3 days',
        eventDate: DateTime.now().add(const Duration(days: 3)),
        location: 'Location 2',
      );

      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Event in 10 days',
        eventDate: DateTime.now().add(const Duration(days: 10)),
        location: 'Location 3',
      );

      // Verify next upcoming event is the earliest one
      final nextEvent = await eventRepo.getNextUpcomingEvent(orgId);
      expect(nextEvent, matcher.isNotNull);
      expect(nextEvent!.name, 'Event in 3 days', reason: 'Should show earliest upcoming event');

      // Verify count
      final upcomingCount = await eventRepo.getUpcomingEventCount(orgId);
      expect(upcomingCount, 3);
    });

    test('Dashboard handles past events correctly', () async {
      // Setup
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

      // Create past events
      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Past Event 1',
        eventDate: DateTime.now().subtract(const Duration(days: 5)),
        location: 'Location 1',
      );

      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Past Event 2',
        eventDate: DateTime.now().subtract(const Duration(days: 10)),
        location: 'Location 2',
      );

      // Create upcoming event
      await eventRepo.createEvent(
        orgId: orgId,
        name: 'Upcoming Event',
        eventDate: DateTime.now().add(const Duration(days: 5)),
        location: 'Location 3',
      );

      // Verify counts
      final upcomingCount = await eventRepo.getUpcomingEventCount(orgId);
      final pastCount = await eventRepo.getPastEventCount(orgId);

      expect(upcomingCount, 1);
      expect(pastCount, 2);

      // Verify next event is the upcoming one, not past
      final nextEvent = await eventRepo.getNextUpcomingEvent(orgId);
      expect(nextEvent, matcher.isNotNull);
      expect(nextEvent!.name, 'Upcoming Event');
      expect(nextEvent.isUpcoming, true);
      expect(nextEvent.isPast, false);
    });

    test('Dashboard statistics update in real-time via streams', () async {
      // Setup
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

      // Watch upcoming events stream
      final upcomingStream = eventRepo.watchUpcomingEvents(orgId);
      
      // Initially should be empty
      var events = await upcomingStream.first;
      expect(events.length, 0);

      // Create an event
      await eventRepo.createEvent(
        orgId: orgId,
        name: 'New Event',
        eventDate: DateTime.now().add(const Duration(days: 5)),
        location: 'Location 1',
      );

      // Stream should update
      events = await upcomingStream.first;
      expect(events.length, 1);
      expect(events[0].name, 'New Event');
    });
  });
}
