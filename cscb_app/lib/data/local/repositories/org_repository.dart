import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/remote/repositories/remote_org_repository.dart';
import 'package:cscb_app/data/remote/repositories/remote_membership_repository.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/core/models/result.dart';
import 'package:cscb_app/core/models/organization_with_membership.dart';
import 'package:cscb_app/core/models/membership_with_user.dart';

class OrgRepository {
  final AppDatabase db;
  final RemoteOrgRepository? _remoteRepo;
  final RemoteMembershipRepository? _remoteMembershipRepo;
  final PermissionRepository? _permissionRepo;
  final UserSession _userSession;

  OrgRepository(
    this.db,
    this._userSession, [
    this._remoteRepo,
    this._remoteMembershipRepo,
    this._permissionRepo,
  ]);

  // ============================================================================
  // ORGANIZATION MANAGEMENT
  // ============================================================================

  /// Register a new organization with the current user as president
  /// Requirements: 1.1, 1.2, 1.3
  Future<Result<String>> registerOrganization({
    required String orgName,
  }) async {
    try {
      if (!_userSession.isLoggedIn) {
        return Result.failure('User not logged in');
      }

      final userId = _userSession.userId!;
      final userName = _userSession.name!;

      return await db.transaction(() async {
        final orgId = const Uuid().v4();
        final membershipId = const Uuid().v4();

        // 1. Create organization locally with status "pending"
        await db.into(db.organizations).insert(
              OrganizationsCompanion.insert(
                id: orgId,
                name: orgName,
                status: const Value('pending'),
              ),
            );

        // 2. Create membership with role "president" and status "approved"
        await db.into(db.memberships).insert(
              MembershipsCompanion.insert(
                id: membershipId,
                userId: userId,
                orgId: orgId,
                role: 'president',
                status: const Value('approved'),
              ),
            );

        // 2.5. Initialize default permissions for the new organization
        if (_permissionRepo != null) {
          try {
            await _permissionRepo.initializeDefaultPermissions(orgId);
          } catch (e) {
            print('Failed to initialize permissions for organization: $e');
            // Continue - permissions can be initialized later via migration
          }
        }

        // 3. Sync to Supabase if available
        if (_remoteRepo != null) {
          try {
            await _remoteRepo.createOrganization({
              'id': orgId,
              'name': orgName,
              'status': 'pending',
              'is_synced': true,
              'deleted': false,
            });

            // Mark as synced locally
            await (db.update(db.organizations)
                  ..where((tbl) => tbl.id.equals(orgId)))
                .write(const OrganizationsCompanion(
              isSynced: Value(true),
            ));
          } catch (e) {
            print('Failed to sync organization to Supabase: $e');
            // Continue - organization saved locally
          }
        }

        // 4. Sync membership to Supabase
        if (_remoteMembershipRepo != null) {
          try {
            await _remoteMembershipRepo.createMembership({
              'id': membershipId,
              'user_id': userId,
              'org_id': orgId,
              'role': 'president',
              'status': 'approved',
              'is_synced': true,
              'deleted': false,
            });

            // Mark as synced locally
            await (db.update(db.memberships)
                  ..where((tbl) => tbl.id.equals(membershipId)))
                .write(const MembershipsCompanion(
              isSynced: Value(true),
            ));
          } catch (e) {
            print('Failed to sync membership to Supabase: $e');
            // Continue - membership saved locally
          }
        }

        return Result.success(orgId);
      });
    } catch (e) {
      return Result.failure('Failed to register organization: $e');
    }
  }

  /// Approve organization (super admin only)
  /// Requirements: 3.2, 3.4
  Future<Result<void>> approveOrganization(String orgId) async {
    try {
      if (!_userSession.isSuperAdmin) {
        return Result.failure('Only super admin can approve organizations');
      }

      await (db.update(db.organizations)..where((tbl) => tbl.id.equals(orgId)))
          .write(OrganizationsCompanion(
        status: const Value('active'),
        clientUpdatedAt: Value(DateTime.now()),
      ));

      // Sync to Supabase
      if (_remoteRepo != null) {
        try {
          await _remoteRepo.approveOrganization(orgId);
        } catch (e) {
          print('Failed to sync approval to Supabase: $e');
        }
      }

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to approve organization: $e');
    }
  }

  /// Reject organization (super admin only)
  /// Requirements: 3.3, 3.4
  Future<Result<void>> rejectOrganization(String orgId) async {
    try {
      if (!_userSession.isSuperAdmin) {
        return Result.failure('Only super admin can reject organizations');
      }

      await (db.update(db.organizations)..where((tbl) => tbl.id.equals(orgId)))
          .write(OrganizationsCompanion(
        status: const Value('rejected'),
        clientUpdatedAt: Value(DateTime.now()),
      ));

      // Sync to Supabase
      if (_remoteRepo != null) {
        try {
          await _remoteRepo.updateOrganization(orgId, {'status': 'rejected'});
        } catch (e) {
          print('Failed to sync rejection to Supabase: $e');
        }
      }

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to reject organization: $e');
    }
  }

  /// Suspend organization (super admin only)
  /// Requirements: 3.5
  Future<Result<void>> suspendOrganization(String orgId) async {
    try {
      if (!_userSession.isSuperAdmin) {
        return Result.failure('Only super admin can suspend organizations');
      }

      await (db.update(db.organizations)..where((tbl) => tbl.id.equals(orgId)))
          .write(OrganizationsCompanion(
        status: const Value('suspended'),
        clientUpdatedAt: Value(DateTime.now()),
      ));

      // Sync to Supabase
      if (_remoteRepo != null) {
        try {
          await _remoteRepo.suspendOrganization(orgId);
        } catch (e) {
          print('Failed to sync suspension to Supabase: $e');
        }
      }

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to suspend organization: $e');
    }
  }

  /// Delete organization (soft delete, super admin only)
  Future<Result<void>> deleteOrganization(String orgId) async {
    try {
      if (!_userSession.isSuperAdmin) {
        return Result.failure('Only super admin can delete organizations');
      }

      await (db.update(db.organizations)..where((tbl) => tbl.id.equals(orgId)))
          .write(OrganizationsCompanion(
        deleted: const Value(true),
        clientUpdatedAt: Value(DateTime.now()),
      ));

      // Sync to Supabase
      if (_remoteRepo != null) {
        try {
          await _remoteRepo.deleteOrganization(orgId);
        } catch (e) {
          print('Failed to sync deletion to Supabase: $e');
        }
      }

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to delete organization: $e');
    }
  }

  // ============================================================================
  // MEMBERSHIP MANAGEMENT
  // ============================================================================

  /// Join an organization (creates pending membership)
  /// Requirements: 5.1, 5.2, 5.3, 5.5
  Future<Result<String>> joinOrganization(String orgId) async {
    try {
      if (!_userSession.isLoggedIn) {
        return Result.failure('User not logged in');
      }

      final userId = _userSession.userId!;

      // Check if membership already exists
      final existingMembership = await (db.select(db.memberships)
            ..where((tbl) =>
                tbl.userId.equals(userId) & tbl.orgId.equals(orgId)))
          .getSingleOrNull();

      if (existingMembership != null) {
        return Result.failure('You already have a membership for this organization');
      }

      // Create pending membership
      final membershipId = const Uuid().v4();
      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: userId,
              orgId: orgId,
              role: 'member',
              status: const Value('pending'),
            ),
          );

      // Sync to Supabase
      if (_remoteMembershipRepo != null) {
        try {
          await _remoteMembershipRepo.createMembership({
            'id': membershipId,
            'user_id': userId,
            'org_id': orgId,
            'role': 'member',
            'status': 'pending',
            'is_synced': true,
            'deleted': false,
          });

          // Mark as synced locally
          await (db.update(db.memberships)
                ..where((tbl) => tbl.id.equals(membershipId)))
              .write(const MembershipsCompanion(
            isSynced: Value(true),
          ));
        } catch (e) {
          print('Failed to sync membership to Supabase: $e');
        }
      }

      return Result.success(membershipId);
    } catch (e) {
      return Result.failure('Failed to join organization: $e');
    }
  }

  /// Approve membership (president only)
  /// Requirements: 6.2, 6.3, 6.4, 6.5
  Future<Result<void>> approveMembership(String membershipId) async {
    try {
      if (!_userSession.isLoggedIn) {
        return Result.failure('User not logged in');
      }

      // Get the membership to check organization
      final membership = await (db.select(db.memberships)
            ..where((tbl) => tbl.id.equals(membershipId)))
          .getSingleOrNull();

      if (membership == null) {
        return Result.failure('Membership not found');
      }

      // Verify current user is president of this organization
      final isPresident = await _isUserPresidentOfOrg(membership.orgId);
      if (!isPresident) {
        return Result.failure('Only presidents can approve memberships');
      }

      // Update membership status to approved
      await (db.update(db.memberships)
            ..where((tbl) => tbl.id.equals(membershipId)))
          .write(MembershipsCompanion(
        status: const Value('approved'),
        clientUpdatedAt: Value(DateTime.now()),
      ));

      // Sync to Supabase
      if (_remoteMembershipRepo != null) {
        try {
          await _remoteMembershipRepo.updateMembership(membershipId, {
            'status': 'approved',
          });
        } catch (e) {
          print('Failed to sync membership approval to Supabase: $e');
        }
      }

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to approve membership: $e');
    }
  }

  /// Reject membership (president only)
  /// Requirements: 6.2, 6.3, 6.4, 6.5
  Future<Result<void>> rejectMembership(String membershipId) async {
    try {
      if (!_userSession.isLoggedIn) {
        return Result.failure('User not logged in');
      }

      // Get the membership to check organization
      final membership = await (db.select(db.memberships)
            ..where((tbl) => tbl.id.equals(membershipId)))
          .getSingleOrNull();

      if (membership == null) {
        return Result.failure('Membership not found');
      }

      // Verify current user is president of this organization
      final isPresident = await _isUserPresidentOfOrg(membership.orgId);
      if (!isPresident) {
        return Result.failure('Only presidents can reject memberships');
      }

      // Update membership status to rejected
      await (db.update(db.memberships)
            ..where((tbl) => tbl.id.equals(membershipId)))
          .write(MembershipsCompanion(
        status: const Value('rejected'),
        clientUpdatedAt: Value(DateTime.now()),
      ));

      // Sync to Supabase
      if (_remoteMembershipRepo != null) {
        try {
          await _remoteMembershipRepo.updateMembership(membershipId, {
            'status': 'rejected',
          });
        } catch (e) {
          print('Failed to sync membership rejection to Supabase: $e');
        }
      }

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to reject membership: $e');
    }
  }

  /// Leave organization
  /// Requirements: 8.1, 8.2, 8.3
  Future<Result<void>> leaveOrganization(String orgId) async {
    try {
      if (!_userSession.isLoggedIn) {
        return Result.failure('User not logged in');
      }

      final userId = _userSession.userId!;

      // Get user's membership
      final membership = await (db.select(db.memberships)
            ..where((tbl) =>
                tbl.userId.equals(userId) & tbl.orgId.equals(orgId)))
          .getSingleOrNull();

      if (membership == null) {
        return Result.failure('You are not a member of this organization');
      }

      // Check if user is president
      if (membership.role == 'president') {
        return Result.failure(
            'Presidents must transfer presidency before leaving');
      }

      // Update membership status to left
      await (db.update(db.memberships)
            ..where((tbl) => tbl.id.equals(membership.id)))
          .write(MembershipsCompanion(
        status: const Value('left'),
        clientUpdatedAt: Value(DateTime.now()),
      ));

      // Sync to Supabase
      if (_remoteMembershipRepo != null) {
        try {
          await _remoteMembershipRepo.updateMembership(membership.id, {
            'status': 'left',
          });
        } catch (e) {
          print('Failed to sync leave to Supabase: $e');
        }
      }

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to leave organization: $e');
    }
  }

  /// Remove member (president only)
  /// Requirements: 10.1, 10.2, 10.3, 10.4
  Future<Result<void>> removeMember(String membershipId) async {
    try {
      if (!_userSession.isLoggedIn) {
        return Result.failure('User not logged in');
      }

      final userId = _userSession.userId!;

      // Get the membership to remove
      final membership = await (db.select(db.memberships)
            ..where((tbl) => tbl.id.equals(membershipId)))
          .getSingleOrNull();

      if (membership == null) {
        return Result.failure('Membership not found');
      }

      // Verify current user is president of this organization
      final isPresident = await _isUserPresidentOfOrg(membership.orgId);
      if (!isPresident) {
        return Result.failure('Only presidents can remove members');
      }

      // Prevent removing self
      if (membership.userId == userId) {
        return Result.failure('Cannot remove yourself');
      }

      // Prevent removing other presidents
      if (membership.role == 'president') {
        return Result.failure('Cannot remove other presidents');
      }

      // Update membership status to removed
      await (db.update(db.memberships)
            ..where((tbl) => tbl.id.equals(membershipId)))
          .write(MembershipsCompanion(
        status: const Value('removed'),
        clientUpdatedAt: Value(DateTime.now()),
      ));

      // Sync to Supabase
      if (_remoteMembershipRepo != null) {
        try {
          await _remoteMembershipRepo.updateMembership(membershipId, {
            'status': 'removed',
          });
        } catch (e) {
          print('Failed to sync member removal to Supabase: $e');
        }
      }

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to remove member: $e');
    }
  }

  /// Transfer presidency
  /// Requirements: 9.1, 9.2, 9.3, 9.4, 9.5
  Future<Result<void>> transferPresidency({
    required String orgId,
    required String newPresidentUserId,
  }) async {
    try {
      if (!_userSession.isLoggedIn) {
        return Result.failure('User not logged in');
      }

      final currentUserId = _userSession.userId!;

      // Verify current user is president
      final isPresident = await _isUserPresidentOfOrg(orgId);
      if (!isPresident) {
        return Result.failure('Only presidents can transfer presidency');
      }

      // Get new president's membership
      final newPresidentMembership = await (db.select(db.memberships)
            ..where((tbl) =>
                tbl.userId.equals(newPresidentUserId) &
                tbl.orgId.equals(orgId)))
          .getSingleOrNull();

      if (newPresidentMembership == null) {
        return Result.failure('Target user is not a member of this organization');
      }

      if (newPresidentMembership.status != 'approved') {
        return Result.failure('Target user must have approved membership');
      }

      // Get current president's membership
      final currentPresidentMembership = await (db.select(db.memberships)
            ..where((tbl) =>
                tbl.userId.equals(currentUserId) & tbl.orgId.equals(orgId)))
          .getSingle();

      // Perform atomic transfer
      await db.transaction(() async {
        // Change new president role to "president"
        await (db.update(db.memberships)
              ..where((tbl) => tbl.id.equals(newPresidentMembership.id)))
            .write(MembershipsCompanion(
          role: const Value('president'),
          clientUpdatedAt: Value(DateTime.now()),
        ));

        // Change former president role to "member"
        await (db.update(db.memberships)
              ..where((tbl) => tbl.id.equals(currentPresidentMembership.id)))
            .write(MembershipsCompanion(
          role: const Value('member'),
          clientUpdatedAt: Value(DateTime.now()),
        ));
      });

      // Sync to Supabase
      if (_remoteMembershipRepo != null) {
        try {
          await _remoteMembershipRepo.updateMembership(
            newPresidentMembership.id,
            {'role': 'president'},
          );
          await _remoteMembershipRepo.updateMembership(
            currentPresidentMembership.id,
            {'role': 'member'},
          );
        } catch (e) {
          print('Failed to sync presidency transfer to Supabase: $e');
        }
      }

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to transfer presidency: $e');
    }
  }

  // ============================================================================
  // QUERY METHODS
  // ============================================================================

  /// Watch user's organizations with membership info
  /// Requirements: 2.1, 2.2
  Stream<List<OrganizationWithMembership>> watchMyOrganizations() {
    if (!_userSession.isLoggedIn) {
      return Stream.value([]);
    }

    final userId = _userSession.userId!;

    final query = db.select(db.organizations).join([
      innerJoin(
        db.memberships,
        db.memberships.orgId.equalsExp(db.organizations.id),
      ),
    ]);

    query.where(
      db.memberships.userId.equals(userId) &
          db.organizations.deleted.equals(false) &
          db.memberships.status.isNotValue('left') &
          db.memberships.status.isNotValue('removed') &
          db.memberships.status.isNotValue('rejected'),
    );

    return query.watch().map((rows) {
      return rows.map((row) {
        final org = row.readTable(db.organizations);
        final membership = row.readTable(db.memberships);
        return OrganizationWithMembership(
          organization: org,
          membership: membership,
        );
      }).toList();
    });
  }

  /// Watch active organizations (excluding user's organizations)
  /// Requirements: 4.1, 4.4, 4.5
  Stream<List<Organization>> watchActiveOrganizations() {
    if (!_userSession.isLoggedIn) {
      return Stream.value([]);
    }

    final userId = _userSession.userId!;

    // Get all active organizations
    final activeOrgsQuery = db.select(db.organizations)
      ..where((tbl) =>
          tbl.status.equals('active') & tbl.deleted.equals(false));

    return activeOrgsQuery.watch().asyncMap((orgs) async {
      // Filter out organizations where user has membership
      final userMemberships = await (db.select(db.memberships)
            ..where((tbl) => tbl.userId.equals(userId)))
          .get();

      final userOrgIds = userMemberships.map((m) => m.orgId).toSet();

      return orgs.where((org) => !userOrgIds.contains(org.id)).toList();
    });
  }

  /// Watch pending organizations (super admin only)
  /// Requirements: 3.1
  Stream<List<Organization>> watchPendingOrganizations() {
    if (!_userSession.isSuperAdmin) {
      return Stream.value([]);
    }

    return (db.select(db.organizations)
          ..where((tbl) =>
              tbl.status.equals('pending') & tbl.deleted.equals(false)))
        .watch();
  }

  /// Watch all organizations (super admin only)
  Stream<List<Organization>> watchAllOrganizations() {
    if (!_userSession.isSuperAdmin) {
      return Stream.value([]);
    }

    return (db.select(db.organizations)
          ..where((tbl) => tbl.deleted.equals(false)))
        .watch();
  }

  /// Watch pending members for an organization
  /// Requirements: 6.1
  Stream<List<MembershipWithUser>> watchPendingMembers(String orgId) {
    final query = db.select(db.memberships).join([
      innerJoin(
        db.users,
        db.users.id.equalsExp(db.memberships.userId),
      ),
      leftOuterJoin(
        db.officerTitles,
        db.officerTitles.id.equalsExp(db.memberships.officerTitleId),
      ),
    ]);

    query.where(
      db.memberships.orgId.equals(orgId) &
          db.memberships.status.equals('pending'),
    );

    return query.watch().map((rows) {
      return rows.map((row) {
        final membership = row.readTable(db.memberships);
        final user = row.readTable(db.users);
        final officerTitle = row.readTableOrNull(db.officerTitles);
        return MembershipWithUser(
          membership: membership,
          user: user,
          officerTitle: officerTitle,
        );
      }).toList();
    }).asBroadcastStream();
  }

  /// Watch approved members for an organization
  /// Requirements: 7.2
  Stream<List<MembershipWithUser>> watchOrganizationMembers(String orgId) {
    final query = db.select(db.memberships).join([
      innerJoin(
        db.users,
        db.users.id.equalsExp(db.memberships.userId),
      ),
      leftOuterJoin(
        db.officerTitles,
        db.officerTitles.id.equalsExp(db.memberships.officerTitleId),
      ),
    ]);

    query.where(
      db.memberships.orgId.equals(orgId) &
          db.memberships.status.equals('approved'),
    );

    return query.watch().map((rows) {
      return rows.map((row) {
        final membership = row.readTable(db.memberships);
        final user = row.readTable(db.users);
        final officerTitle = row.readTableOrNull(db.officerTitles);
        return MembershipWithUser(
          membership: membership,
          user: user,
          officerTitle: officerTitle,
        );
      }).toList();
    }).asBroadcastStream();
  }

  /// Search organizations by name
  /// Requirements: 11.1, 11.2, 11.3, 11.4, 11.5
  Stream<List<Organization>> searchOrganizations(String query) {
    if (!_userSession.isLoggedIn) {
      return Stream.value([]);
    }

    final userId = _userSession.userId!;
    final searchQuery = '%${query.toLowerCase()}%';

    // Get active organizations matching search
    final orgsQuery = db.select(db.organizations)
      ..where((tbl) =>
          tbl.status.equals('active') &
          tbl.deleted.equals(false) &
          tbl.name.lower().like(searchQuery));

    return orgsQuery.watch().asyncMap((orgs) async {
      // Filter out organizations where user has membership
      final userMemberships = await (db.select(db.memberships)
            ..where((tbl) => tbl.userId.equals(userId)))
          .get();

      final userOrgIds = userMemberships.map((m) => m.orgId).toSet();

      return orgs.where((org) => !userOrgIds.contains(org.id)).toList();
    });
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Check if current user is president of an organization
  Future<bool> _isUserPresidentOfOrg(String orgId) async {
    if (!_userSession.isLoggedIn) return false;

    final userId = _userSession.userId!;

    final membership = await (db.select(db.memberships)
          ..where((tbl) =>
              tbl.userId.equals(userId) &
              tbl.orgId.equals(orgId) &
              tbl.role.equals('president') &
              tbl.status.equals('approved')))
        .getSingleOrNull();

    return membership != null;
  }
}
