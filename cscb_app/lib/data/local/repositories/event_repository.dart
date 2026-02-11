import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/core/models/result.dart';
import 'package:cscb_app/core/models/event_model.dart';
import 'package:cscb_app/core/models/student_attendance.dart';

class EventRepository {
  final AppDatabase db;
  final UserSession _userSession;

  EventRepository(this.db, this._userSession);

  /// Get all events (for simplified app without org filtering)
  Future<List<Event>> getAllEvents() async {
    final query = db.select(db.events)
      ..where((tbl) => tbl.deleted.equals(false))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.eventDate)]);

    return await query.get();
  }

  /// Get attendance count for an event
  Future<int> getAttendanceCount(String eventId) async {
    final query = db.selectOnly(db.attendance)
      ..addColumns([db.attendance.id.count()])
      ..where(
        db.attendance.eventId.equals(eventId) &
            db.attendance.deleted.equals(false),
      );

    final result = await query.getSingle();
    return result.read(db.attendance.id.count()) ?? 0;
  }

  /// Record attendance for a student at an event from QR code
  Future<Result<StudentAttendance>> recordStudentAttendance({
    required String eventId,
    required String qrData,
  }) async {
    try {
      final attendanceId = const Uuid().v4();
      
      // Parse QR code data
      final studentData = StudentAttendance.fromQRCode(qrData, eventId, attendanceId);
      if (studentData == null) {
        return Result.failure('Invalid QR code format. Expected: studentNo|lastName|firstName|program|yearLevel');
      }

      // Check if already attended
      final existing = await (db.select(db.attendance)
            ..where((tbl) =>
                tbl.eventId.equals(eventId) &
                tbl.studentNumber.equals(studentData.studentNumber) &
                tbl.deleted.equals(false)))
          .getSingleOrNull();

      if (existing != null) {
        return Result.failure('${studentData.fullName} has already checked in');
      }

      // Record attendance with student details
      await db.into(db.attendance).insert(
            AttendanceCompanion.insert(
              id: attendanceId,
              eventId: eventId,
              userId: studentData.studentNumber, // Use student number as userId
              studentNumber: studentData.studentNumber,
              lastName: studentData.lastName,
              firstName: studentData.firstName,
              program: studentData.program,
              yearLevel: studentData.yearLevel,
              timestamp: DateTime.now(),
              status: const Value('present'),
            ),
          );

      return Result.success(studentData);
    } catch (e) {
      return Result.failure('Failed to record attendance: $e');
    }
  }

  /// Get attendance list with student details
  Future<List<StudentAttendance>> getStudentAttendanceList(String eventId) async {
    final query = db.select(db.attendance)
      ..where((tbl) =>
          tbl.eventId.equals(eventId) & tbl.deleted.equals(false))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.timestamp)]);

    final records = await query.get();
    
    return records.map((record) => StudentAttendance(
      id: record.id,
      eventId: record.eventId,
      studentNumber: record.studentNumber,
      lastName: record.lastName,
      firstName: record.firstName,
      program: record.program,
      yearLevel: record.yearLevel,
      timestamp: record.timestamp,
      status: record.status,
    )).toList();
  }

  /// Create a new event (simplified version)
  Future<void> createEventSimple(EventsCompanion event) async {
    await db.into(db.events).insert(event);
  }

  /// Create a new event with full details
  /// Requirements: 3.5, 12.1
  Future<Result<String>> createEvent({
    required String orgId,
    required String name,
    required DateTime eventDate,
    required String location,
    String? description,
    int? maxAttendees,
  }) async {
    try {
      if (!_userSession.isLoggedIn) {
        return Result.failure('User not logged in');
      }

      final userId = _userSession.userId!;
      final eventId = const Uuid().v4();

      // Create event locally
      await db.into(db.events).insert(
            EventsCompanion.insert(
              id: eventId,
              orgId: orgId,
              name: name,
              eventDate: eventDate,
              location: location,
              description: Value(description),
              maxAttendees: Value(maxAttendees),
              createdBy: userId,
              createdAt: Value(DateTime.now()),
              clientUpdatedAt: Value(DateTime.now()),
            ),
          );

      // TODO: Sync to Supabase when RemoteEventRepository is implemented

      return Result.success(eventId);
    } catch (e) {
      return Result.failure('Failed to create event: $e');
    }
  }

  /// Watch upcoming events for an organization
  /// Requirements: 2.1, 9.3
  Stream<List<EventModel>> watchUpcomingEvents(String orgId) {
    final now = DateTime.now();

    final query = db.select(db.events)
      ..where((tbl) =>
          tbl.orgId.equals(orgId) &
          tbl.deleted.equals(false) &
          tbl.eventDate.isBiggerThanValue(now))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.eventDate)]);

    return query.watch().map((events) {
      return events.map((event) => EventModel.fromEvent(event)).toList();
    });
  }

  /// Watch past events for an organization
  /// Requirements: 9.3
  Stream<List<EventModel>> watchPastEvents(String orgId) {
    final now = DateTime.now();

    final query = db.select(db.events)
      ..where((tbl) =>
          tbl.orgId.equals(orgId) &
          tbl.deleted.equals(false) &
          tbl.eventDate.isSmallerThanValue(now))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.eventDate)]);

    return query.watch().map((events) {
      return events.map((event) => EventModel.fromEvent(event)).toList();
    });
  }

  /// Get the next upcoming event for an organization
  /// Requirements: 1.5, 2.1
  Future<EventModel?> getNextUpcomingEvent(String orgId) async {
    final now = DateTime.now();

    final query = db.select(db.events)
      ..where((tbl) =>
          tbl.orgId.equals(orgId) &
          tbl.deleted.equals(false) &
          tbl.eventDate.isBiggerThanValue(now))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.eventDate)])
      ..limit(1);

    final event = await query.getSingleOrNull();
    return event != null ? EventModel.fromEvent(event) : null;
  }

  /// Get count of upcoming events for an organization
  /// Requirements: 1.3, 8.2
  Future<int> getUpcomingEventCount(String orgId) async {
    final now = DateTime.now();

    final query = db.selectOnly(db.events)
      ..addColumns([db.events.id.count()])
      ..where(
        db.events.orgId.equals(orgId) &
            db.events.deleted.equals(false) &
            db.events.eventDate.isBiggerThanValue(now),
      );

    final result = await query.getSingle();
    return result.read(db.events.id.count()) ?? 0;
  }

  /// Get count of past events for an organization
  /// Requirements: 1.4, 8.3
  Future<int> getPastEventCount(String orgId) async {
    final now = DateTime.now();

    final query = db.selectOnly(db.events)
      ..addColumns([db.events.id.count()])
      ..where(
        db.events.orgId.equals(orgId) &
            db.events.deleted.equals(false) &
            db.events.eventDate.isSmallerThanValue(now),
      );

    final result = await query.getSingle();
    return result.read(db.events.id.count()) ?? 0;
  }

  /// Update an event
  Future<Result<void>> updateEvent(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final companion = EventsCompanion(
        name: updates.containsKey('name')
            ? Value(updates['name'] as String)
            : const Value.absent(),
        description: updates.containsKey('description')
            ? Value(updates['description'] as String?)
            : const Value.absent(),
        eventDate: updates.containsKey('eventDate')
            ? Value(updates['eventDate'] as DateTime)
            : const Value.absent(),
        location: updates.containsKey('location')
            ? Value(updates['location'] as String)
            : const Value.absent(),
        maxAttendees: updates.containsKey('maxAttendees')
            ? Value(updates['maxAttendees'] as int?)
            : const Value.absent(),
        clientUpdatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      );

      await (db.update(db.events)..where((tbl) => tbl.id.equals(eventId)))
          .write(companion);

      // TODO: Sync to Supabase when RemoteEventRepository is implemented

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to update event: $e');
    }
  }

  /// Delete an event (soft delete)
  Future<Result<void>> deleteEvent(String eventId) async {
    try {
      await (db.update(db.events)..where((tbl) => tbl.id.equals(eventId)))
          .write(EventsCompanion(
        deleted: const Value(true),
        clientUpdatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ));

      // TODO: Sync to Supabase when RemoteEventRepository is implemented

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to delete event: $e');
    }
  }
}
