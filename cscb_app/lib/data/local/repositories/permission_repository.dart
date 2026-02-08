import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/core/models/result.dart';
import 'package:cscb_app/core/models/permission.dart';
import 'package:cscb_app/core/models/permission_model.dart';

class PermissionRepository {
  final AppDatabase db;
  final UserSession _userSession;

  PermissionRepository(this.db, this._userSession);

  /// Initialize default permissions for a new organization
  /// Requirements: 6.1
  Future<void> initializeDefaultPermissions(String orgId) async {
    // Create default permission entries for all available permissions
    // Set all permissions to false initially
    for (final permission in Permission.all) {
      final permissionId = const Uuid().v4();
      
      await db.into(db.organizationPermissions).insert(
            OrganizationPermissionsCompanion.insert(
              id: permissionId,
              orgId: orgId,
              permissionKey: permission.key,
              enabledForOfficers: const Value(false),
              clientUpdatedAt: Value(DateTime.now()),
            ),
          );
    }
  }

  /// Get organization's default officer permissions
  /// Requirements: 5.2
  Future<List<PermissionModel>> getOfficerPermissions(String orgId) async {
    // Query OrganizationPermissions for orgId
    final query = db.select(db.organizationPermissions)
      ..where((tbl) => tbl.orgId.equals(orgId) & tbl.deleted.equals(false));

    final orgPermissions = await query.get();

    // Convert to PermissionModel list
    final permissionModels = <PermissionModel>[];
    
    for (final permission in Permission.all) {
      // Find the organization permission entry for this permission key
      final orgPerm = orgPermissions.firstWhere(
        (p) => p.permissionKey == permission.key,
        orElse: () => OrganizationPermission(
          id: '',
          orgId: orgId,
          permissionKey: permission.key,
          enabledForOfficers: false,
          isSynced: false,
          clientUpdatedAt: null,
          deleted: false,
        ),
      );

      permissionModels.add(PermissionModel(
        key: permission.key,
        label: permission.label,
        description: permission.description,
        isGranted: orgPerm.enabledForOfficers,
      ));
    }

    return permissionModels;
  }

  /// Update organization's default officer permissions
  /// Requirements: 5.3, 5.4, 12.3
  Future<Result<void>> updateOfficerPermissions(
    String orgId,
    Map<String, bool> permissions,
  ) async {
    try {
      // Update multiple permissions atomically using transaction
      await db.transaction(() async {
        for (final entry in permissions.entries) {
          final permissionKey = entry.key;
          final isEnabled = entry.value;

          // Find existing permission entry
          final query = db.select(db.organizationPermissions)
            ..where((tbl) =>
                tbl.orgId.equals(orgId) &
                tbl.permissionKey.equals(permissionKey) &
                tbl.deleted.equals(false));

          final existingPerm = await query.getSingleOrNull();

          if (existingPerm != null) {
            // Update existing permission
            await (db.update(db.organizationPermissions)
                  ..where((tbl) => tbl.id.equals(existingPerm.id)))
                .write(OrganizationPermissionsCompanion(
              enabledForOfficers: Value(isEnabled),
              clientUpdatedAt: Value(DateTime.now()),
              isSynced: const Value(false),
            ));
          } else {
            // Create new permission entry if it doesn't exist
            final permissionId = const Uuid().v4();
            await db.into(db.organizationPermissions).insert(
                  OrganizationPermissionsCompanion.insert(
                    id: permissionId,
                    orgId: orgId,
                    permissionKey: permissionKey,
                    enabledForOfficers: Value(isEnabled),
                    clientUpdatedAt: Value(DateTime.now()),
                  ),
                );
          }
        }
      });

      // TODO: Sync to Supabase when RemotePermissionRepository is implemented

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to update officer permissions: $e');
    }
  }

  /// Get individual member permissions
  /// Requirements: 15.1
  Future<List<PermissionModel>> getMemberPermissions(String membershipId) async {
    // Get the membership to find the orgId
    final membership = await (db.select(db.memberships)
          ..where((tbl) => tbl.id.equals(membershipId) & tbl.deleted.equals(false)))
        .getSingleOrNull();

    if (membership == null) {
      return [];
    }

    // Query MemberPermissions for membershipId
    final memberPermsQuery = db.select(db.memberPermissions)
      ..where((tbl) =>
          tbl.membershipId.equals(membershipId) & tbl.deleted.equals(false));

    final memberPerms = await memberPermsQuery.get();

    // Get organization default permissions
    final orgPermsQuery = db.select(db.organizationPermissions)
      ..where((tbl) =>
          tbl.orgId.equals(membership.orgId) & tbl.deleted.equals(false));

    final orgPerms = await orgPermsQuery.get();

    // Merge with organization default permissions
    final permissionModels = <PermissionModel>[];

    for (final permission in Permission.all) {
      // Check for individual override first
      final memberPerm = memberPerms.firstWhere(
        (p) => p.permissionKey == permission.key,
        orElse: () => MemberPermission(
          id: '',
          membershipId: membershipId,
          permissionKey: permission.key,
          isGranted: false,
          isSynced: false,
          clientUpdatedAt: null,
          deleted: false,
        ),
      );

      // If member has an override (id is not empty), use it
      bool isGranted;
      if (memberPerm.id.isNotEmpty) {
        isGranted = memberPerm.isGranted;
      } else {
        // Otherwise, use organization default
        final orgPerm = orgPerms.firstWhere(
          (p) => p.permissionKey == permission.key,
          orElse: () => OrganizationPermission(
            id: '',
            orgId: membership.orgId,
            permissionKey: permission.key,
            enabledForOfficers: false,
            isSynced: false,
            clientUpdatedAt: null,
            deleted: false,
          ),
        );
        isGranted = orgPerm.enabledForOfficers;
      }

      permissionModels.add(PermissionModel(
        key: permission.key,
        label: permission.label,
        description: permission.description,
        isGranted: isGranted,
      ));
    }

    return permissionModels;
  }

  /// Update individual member permission overrides
  /// Requirements: 15.2, 15.5
  Future<Result<void>> updateMemberPermissions(
    String membershipId,
    Map<String, bool> permissions,
  ) async {
    try {
      // Update individual member permission overrides atomically
      await db.transaction(() async {
        for (final entry in permissions.entries) {
          final permissionKey = entry.key;
          final isGranted = entry.value;

          // Find existing member permission override
          final query = db.select(db.memberPermissions)
            ..where((tbl) =>
                tbl.membershipId.equals(membershipId) &
                tbl.permissionKey.equals(permissionKey) &
                tbl.deleted.equals(false));

          final existingPerm = await query.getSingleOrNull();

          if (existingPerm != null) {
            // Update existing override
            await (db.update(db.memberPermissions)
                  ..where((tbl) => tbl.id.equals(existingPerm.id)))
                .write(MemberPermissionsCompanion(
              isGranted: Value(isGranted),
              clientUpdatedAt: Value(DateTime.now()),
              isSynced: const Value(false),
            ));
          } else {
            // Create new override entry
            final permissionId = const Uuid().v4();
            await db.into(db.memberPermissions).insert(
                  MemberPermissionsCompanion.insert(
                    id: permissionId,
                    membershipId: membershipId,
                    permissionKey: permissionKey,
                    isGranted: isGranted,
                    clientUpdatedAt: Value(DateTime.now()),
                  ),
                );
          }
        }
      });

      // TODO: Sync to Supabase when RemotePermissionRepository is implemented

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to update member permissions: $e');
    }
  }

  /// Check if user has a specific permission in an organization
  /// Requirements: 7.1, 7.2, 7.4
  Future<bool> hasPermission(String orgId, String permissionKey) async {
    if (!_userSession.isLoggedIn) {
      return false;
    }

    final userId = _userSession.userId!;

    // Get user's membership in the organization
    final membershipQuery = db.select(db.memberships)
      ..where((tbl) =>
          tbl.userId.equals(userId) &
          tbl.orgId.equals(orgId) &
          tbl.deleted.equals(false) &
          tbl.status.equals('approved'));

    final membership = await membershipQuery.getSingleOrNull();

    if (membership == null) {
      return false;
    }

    // 1. Check if user is president (return true)
    if (membership.role == 'president') {
      return true;
    }

    // 2. Check individual overrides
    final memberPermQuery = db.select(db.memberPermissions)
      ..where((tbl) =>
          tbl.membershipId.equals(membership.id) &
          tbl.permissionKey.equals(permissionKey) &
          tbl.deleted.equals(false));

    final memberPerm = await memberPermQuery.getSingleOrNull();

    if (memberPerm != null) {
      return memberPerm.isGranted;
    }

    // 3. Check officer default permissions
    if (membership.officerTitleId != null) {
      final orgPermQuery = db.select(db.organizationPermissions)
        ..where((tbl) =>
            tbl.orgId.equals(orgId) &
            tbl.permissionKey.equals(permissionKey) &
            tbl.deleted.equals(false));

      final orgPerm = await orgPermQuery.getSingleOrNull();

      if (orgPerm != null) {
        return orgPerm.enabledForOfficers;
      }
    }

    // 4. Return false for regular members
    return false;
  }
}
