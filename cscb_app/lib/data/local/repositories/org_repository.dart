import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:cscb_app/data/local/db/app_database.dart';

class OrgRepository {
  final AppDatabase db;

  OrgRepository(this.db);

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
            ),
            mode: InsertMode.insertOrReplace,
          );

      // 2. Create Org
      await db
          .into(db.organizations)
          .insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: orgName,
              status: const Value('pending'),
            ),
          );

      // 3. Create Membership
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
}
