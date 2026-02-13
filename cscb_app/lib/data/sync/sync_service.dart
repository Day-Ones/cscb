import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../local/db/app_database.dart';
import '../remote/repositories/remote_user_repository.dart';
import '../remote/repositories/remote_org_repository.dart';
import '../remote/repositories/remote_event_repository.dart';
import '../remote/repositories/remote_attendance_repository.dart';

/// Service to handle syncing between local SQLite and Supabase
class SyncService {
  final AppDatabase _db;
  final RemoteUserRepository _remoteUserRepo;
  final RemoteOrgRepository _remoteOrgRepo;
  final RemoteEventRepository _remoteEventRepo;
  final RemoteAttendanceRepository _remoteAttendanceRepo;

  SyncService(
    this._db,
    this._remoteUserRepo,
    this._remoteOrgRepo,
    this._remoteEventRepo,
    this._remoteAttendanceRepo,
  );

  /// Sync all data (users, organizations, events, attendance)
  Future<SyncResult> syncAll() async {
    try {
      await syncUsers();
      await syncOrganizations();
      await syncEvents();
      await syncAttendance();
      return SyncResult.success('All data synced successfully');
    } catch (e) {
      return SyncResult.failure('Sync failed: $e');
    }
  }

  /// Sync users from local to Supabase
  Future<void> syncUsers() async {
    // Get all unsynced users from local database
    final unsyncedUsers = await (_db.select(_db.users)
          ..where((tbl) => tbl.isSynced.equals(false) & tbl.deleted.equals(false)))
        .get();

    for (var user in unsyncedUsers) {
      try {
        // Check if user exists in Supabase
        final remoteUser = await _remoteUserRepo.getUserByEmail(user.email);

        if (remoteUser == null) {
          // Create new user in Supabase
          await _remoteUserRepo.createUser({
            'id': user.id,
            'name': user.name,
            'email': user.email,
            'password_hash': user.passwordHash,
            'role': user.role,
            'client_updated_at': user.clientUpdatedAt?.toIso8601String(),
            'deleted': user.deleted,
          });
        } else {
          // Update existing user in Supabase
          await _remoteUserRepo.updateUser(user.id, {
            'name': user.name,
            'password_hash': user.passwordHash,
            'role': user.role,
            'client_updated_at': user.clientUpdatedAt?.toIso8601String(),
            'deleted': user.deleted,
          });
        }

        // Mark as synced in local database
        await (_db.update(_db.users)..where((tbl) => tbl.id.equals(user.id)))
            .write(UsersCompanion(
          isSynced: const Value(true),
          clientUpdatedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('Failed to sync user ${user.email}: $e');
        // Continue with next user
      }
    }
  }

  /// Sync organizations from local to Supabase
  Future<void> syncOrganizations() async {
    // Get all unsynced organizations from local database
    final unsyncedOrgs = await (_db.select(_db.organizations)
          ..where((tbl) => tbl.isSynced.equals(false) & tbl.deleted.equals(false)))
        .get();

    for (var org in unsyncedOrgs) {
      try {
        // Create or update organization in Supabase
        await _remoteOrgRepo.createOrganization({
          'id': org.id,
          'name': org.name,
          'status': org.status,
          'client_updated_at': org.clientUpdatedAt?.toIso8601String(),
          'deleted': org.deleted,
        });

        // Mark as synced in local database
        await (_db.update(_db.organizations)..where((tbl) => tbl.id.equals(org.id)))
            .write(OrganizationsCompanion(
          isSynced: const Value(true),
          clientUpdatedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('Failed to sync organization ${org.name}: $e');
        // Continue with next organization
      }
    }
  }

  /// Pull data from Supabase to local database
  Future<void> pullFromSupabase() async {
    try {
      // Pull users
      final remoteUsers = await _remoteUserRepo.getAllUsers();
      for (var userData in remoteUsers) {
        await _db.into(_db.users).insertOnConflictUpdate(
          UsersCompanion(
            id: Value(userData['id']),
            name: Value(userData['name']),
            email: Value(userData['email']),
            passwordHash: Value(userData['password_hash']),
            role: Value(userData['role']),
            isSynced: const Value(true),
            deleted: Value(userData['deleted'] ?? false),
          ),
        );
      }

      // Pull organizations
      final remoteOrgs = await _remoteOrgRepo.getAllOrganizations();
      for (var orgData in remoteOrgs) {
        await _db.into(_db.organizations).insertOnConflictUpdate(
          OrganizationsCompanion(
            id: Value(orgData['id']),
            name: Value(orgData['name']),
            status: Value(orgData['status']),
            isSynced: const Value(true),
            deleted: Value(orgData['deleted'] ?? false),
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to pull data from Supabase: $e');
    }
  }

  /// Sync events from local to Supabase
  Future<void> syncEvents() async {
    // Get all unsynced events from local database
    final unsyncedEvents = await (_db.select(_db.events)
          ..where((tbl) => tbl.isSynced.equals(false) & tbl.deleted.equals(false)))
        .get();

    for (var event in unsyncedEvents) {
      try {
        // Create or update event in Supabase
        await _remoteEventRepo.createEvent({
          'id': event.id,
          'org_id': event.orgId,
          'name': event.name,
          'description': event.description,
          'event_date': event.eventDate.toIso8601String(),
          'location': event.location,
          'max_attendees': event.maxAttendees,
          'created_by': event.createdBy,
          'created_at': event.createdAt?.toIso8601String(),
          'client_updated_at': event.clientUpdatedAt?.toIso8601String(),
          'deleted': event.deleted,
        });

        // Mark as synced in local database
        await (_db.update(_db.events)..where((tbl) => tbl.id.equals(event.id)))
            .write(EventsCompanion(
          isSynced: const Value(true),
          clientUpdatedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('Failed to sync event ${event.name}: $e');
        // Continue with next event
      }
    }
  }

  /// Sync attendance from local to Supabase
  Future<void> syncAttendance() async {
    // Get all unsynced attendance from local database
    final unsyncedAttendance = await (_db.select(_db.attendance)
          ..where((tbl) => tbl.isSynced.equals(false) & tbl.deleted.equals(false)))
        .get();

    for (var attendance in unsyncedAttendance) {
      try {
        // Check if attendance already exists in Supabase for this student and event
        final existingAttendance = await _remoteAttendanceRepo.getAttendanceByEventAndStudent(
          attendance.eventId,
          attendance.studentNumber,
        );

        if (existingAttendance != null) {
          // Duplicate found - keep the earlier one
          final existingTimestamp = DateTime.parse(existingAttendance['timestamp']);
          final localTimestamp = attendance.timestamp;

          if (localTimestamp.isBefore(existingTimestamp)) {
            // Local record is earlier - update Supabase with earlier timestamp
            await _remoteAttendanceRepo.updateAttendance(existingAttendance['id'], {
              'timestamp': localTimestamp.toIso8601String(),
              'client_updated_at': attendance.clientUpdatedAt?.toIso8601String(),
            });
            debugPrint('Updated Supabase with earlier attendance for ${attendance.studentNumber}');
          } else {
            // Remote record is earlier - just mark local as synced
            debugPrint('Kept earlier Supabase attendance for ${attendance.studentNumber}');
          }
        } else {
          // No duplicate - create new attendance in Supabase
          await _remoteAttendanceRepo.createAttendance({
            'id': attendance.id,
            'event_id': attendance.eventId,
            'student_number': attendance.studentNumber,
            'last_name': attendance.lastName,
            'first_name': attendance.firstName,
            'program': attendance.program,
            'year_level': attendance.yearLevel,
            'timestamp': attendance.timestamp.toIso8601String(),
            'status': attendance.status,
            'client_updated_at': attendance.clientUpdatedAt?.toIso8601String(),
            'deleted': attendance.deleted,
          });
        }

        // Mark as synced in local database
        await (_db.update(_db.attendance)..where((tbl) => tbl.id.equals(attendance.id)))
            .write(AttendanceCompanion(
          isSynced: const Value(true),
          clientUpdatedAt: Value(DateTime.now()),
        ));
      } catch (e) {
        debugPrint('Failed to sync attendance ${attendance.id}: $e');
        // Continue with next attendance
      }
    }
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;

  SyncResult.success(this.message) : success = true;
  SyncResult.failure(this.message) : success = false;
}
