import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../local/db/app_database.dart';
import '../remote/repositories/remote_user_repository.dart';
import '../remote/repositories/remote_org_repository.dart';

/// Service to handle syncing between local SQLite and Supabase
class SyncService {
  final AppDatabase _db;
  final RemoteUserRepository _remoteUserRepo;
  final RemoteOrgRepository _remoteOrgRepo;

  SyncService(
    this._db,
    this._remoteUserRepo,
    this._remoteOrgRepo,
  );

  /// Sync all data (users, organizations, etc.)
  Future<SyncResult> syncAll() async {
    try {
      await syncUsers();
      await syncOrganizations();
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
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String message;

  SyncResult.success(this.message) : success = true;
  SyncResult.failure(this.message) : success = false;
}
