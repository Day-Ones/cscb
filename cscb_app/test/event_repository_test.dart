import 'package:flutter_test/flutter_test.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/local/repositories/event_repository.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:drift/native.dart';

void main() {
  late AppDatabase db;
  late EventRepository eventRepository;
  late UserSession userSession;

  setUp(() {
    // Create in-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());
    userSession = UserSession();
    eventRepository = EventRepository(db, userSession);
  });

  tearDown(() async {
    await db.close();
  });

  group('EventRepository', () {
    test('createEvent creates event successfully when user is logged in',
        () async {
      // Arrange
      userSession.setCurrentUser(
        userId: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        role: 'member',
      );

      // Act
      final result = await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Test Event',
        eventDate: DateTime.now().add(const Duration(days: 7)),
        location: 'Test Location',
        description: 'Test Description',
        maxAttendees: 50,
      );

      // Assert
      expect(result.success, true);
      expect(result.data, isNotNull);
    });

    test('createEvent fails when user is not logged in', () async {
      // Act
      final result = await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Test Event',
        eventDate: DateTime.now().add(const Duration(days: 7)),
        location: 'Test Location',
      );

      // Assert
      expect(result.success, false);
      expect(result.errorMessage, contains('not logged in'));
    });

    test('getUpcomingEventCount returns correct count', () async {
      // Arrange
      userSession.setCurrentUser(
        userId: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        role: 'member',
      );
      
      // Create 3 upcoming events
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Event 1',
        eventDate: DateTime.now().add(const Duration(days: 1)),
        location: 'Location 1',
      );
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Event 2',
        eventDate: DateTime.now().add(const Duration(days: 2)),
        location: 'Location 2',
      );
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Event 3',
        eventDate: DateTime.now().add(const Duration(days: 3)),
        location: 'Location 3',
      );

      // Act
      final count = await eventRepository.getUpcomingEventCount('test-org-id');

      // Assert
      expect(count, 3);
    });

    test('getPastEventCount returns correct count', () async {
      // Arrange
      userSession.setCurrentUser(
        userId: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        role: 'member',
      );
      
      // Create 2 past events
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Past Event 1',
        eventDate: DateTime.now().subtract(const Duration(days: 1)),
        location: 'Location 1',
      );
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Past Event 2',
        eventDate: DateTime.now().subtract(const Duration(days: 2)),
        location: 'Location 2',
      );

      // Act
      final count = await eventRepository.getPastEventCount('test-org-id');

      // Assert
      expect(count, 2);
    });

    test('getNextUpcomingEvent returns earliest upcoming event', () async {
      // Arrange
      userSession.setCurrentUser(
        userId: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        role: 'member',
      );
      
      // Create events with different dates
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Event in 3 days',
        eventDate: DateTime.now().add(const Duration(days: 3)),
        location: 'Location 3',
      );
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Event in 1 day',
        eventDate: DateTime.now().add(const Duration(days: 1)),
        location: 'Location 1',
      );
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Event in 2 days',
        eventDate: DateTime.now().add(const Duration(days: 2)),
        location: 'Location 2',
      );

      // Act
      final nextEvent = await eventRepository.getNextUpcomingEvent('test-org-id');

      // Assert
      expect(nextEvent, isNotNull);
      expect(nextEvent!.name, 'Event in 1 day');
    });

    test('getNextUpcomingEvent returns null when no upcoming events', () async {
      // Act
      final nextEvent = await eventRepository.getNextUpcomingEvent('test-org-id');

      // Assert
      expect(nextEvent, isNull);
    });

    test('watchUpcomingEvents streams upcoming events in ascending order',
        () async {
      // Arrange
      userSession.setCurrentUser(
        userId: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        role: 'member',
      );
      
      // Create events
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Event 3',
        eventDate: DateTime.now().add(const Duration(days: 3)),
        location: 'Location 3',
      );
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Event 1',
        eventDate: DateTime.now().add(const Duration(days: 1)),
        location: 'Location 1',
      );

      // Act & Assert
      final stream = eventRepository.watchUpcomingEvents('test-org-id');
      final events = await stream.first;

      expect(events.length, 2);
      expect(events[0].name, 'Event 1'); // Should be first (earliest date)
      expect(events[1].name, 'Event 3');
    });

    test('watchPastEvents streams past events in descending order', () async {
      // Arrange
      userSession.setCurrentUser(
        userId: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        role: 'member',
      );
      
      // Create past events
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Event 3 days ago',
        eventDate: DateTime.now().subtract(const Duration(days: 3)),
        location: 'Location 3',
      );
      await eventRepository.createEvent(
        orgId: 'test-org-id',
        name: 'Event 1 day ago',
        eventDate: DateTime.now().subtract(const Duration(days: 1)),
        location: 'Location 1',
      );

      // Act & Assert
      final stream = eventRepository.watchPastEvents('test-org-id');
      final events = await stream.first;

      expect(events.length, 2);
      expect(events[0].name, 'Event 1 day ago'); // Should be first (most recent)
      expect(events[1].name, 'Event 3 days ago');
    });
  });
}
