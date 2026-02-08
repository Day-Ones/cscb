import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/remote/repositories/remote_org_repository.dart';

class OrgRepository {
  final AppDatabase db;
  final RemoteOrgRepository? _remoteRepo;

  OrgRepository(this.db, [this._remoteRepo]);

  // --- WRITE OPERATIONS ---
  Future<void> registerPresident({
    required String userName,
    required String orgName,
  }) async {
    return db.transaction(() async {
      final userId = 'current-user-id'; // Mock user ID for now
      final orgId = const Uuid().v4();
      final membershipId = const Uuid().v4();

      // 1. Ensure user exists locally
      // We use insertOnConflictUpdate to avoid crashing if user already exists
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: userId,
              name: userName,
              email: 'user@example.com',
              passwordHash: '', // Empty for now - will be set during proper user creation
            ),
            mode: InsertMode.insertOrReplace,
          );

      // 2. Create Org locally
      await db
          .into(db.organizations)
          .insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: orgName,
              status: const Value('pending'),
            ),
          );

      // 3. Create Membership locally
      await db
          .into(db.memberships)
          .insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: userId,
              orgId: orgId,
              role: 'president',
              status: const Value('approved'),
            ),
          );

      // 4. Sync to Supabase if remote repo is available
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
          await (db.update(db.organizations)..where((tbl) => tbl.id.equals(orgId)))
              .write(OrganizationsCompanion(
            isSynced: const Value(true),
          ));
        } catch (e) {
          // If sync fails, organization stays local with isSynced = false
          print('Failed to sync organization to Supabase: $e');
        }
      }
    });
  }

  // --- READ OPERATIONS ---

  // Get Orgs where I am a member
  Stream<List<Organization>> watchMyOrganizations() {
    // We select from Organizations, but join with Memberships
    final query = db.select(db.organizations).join([
      innerJoin(
        db.memberships,
        db.memberships.orgId.equalsExp(db.organizations.id),
      ),
    ]);

    // Filter: where memberships.userId == 'current-user-id'
    query.where(db.memberships.userId.equals('current-user-id'));

    // Map the result rows back to the Organization table class
    return query.map((row) => row.readTable(db.organizations)).watch();
  }

  // Get Orgs where I am NOT a member (simplified: just show all active ones)
  Stream<List<Organization>> watchOtherOrganizations() {
    return (db.select(
          db.organizations,
        )..where((tbl) => tbl.status.equals('active'))) // Drift 'equals' syntax
        .watch();
  }

  // Get ALL organizations for admin approval (including pending)
  Stream<List<Organization>> watchAllOrganizations() {
    return (db.select(
          db.organizations,
        )..where((tbl) => tbl.deleted.equals(false)))
        .watch();
  }

  // Approve organization (change status to active)
  Future<void> approveOrganization(String orgId) async {
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
  }

  // Suspend organization
  Future<void> suspendOrganization(String orgId) async {
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
  }

  // Delete organization (soft delete)
  Future<void> deleteOrganization(String orgId) async {
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
  }
}
