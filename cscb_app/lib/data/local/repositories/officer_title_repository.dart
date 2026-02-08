import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/core/models/result.dart';
import 'package:cscb_app/core/models/officer_title_model.dart';

class OfficerTitleRepository {
  final AppDatabase db;

  OfficerTitleRepository(this.db);

  /// Create a new officer title for an organization
  /// Requirements: 4.2, 14.1
  Future<Result<String>> createOfficerTitle(String orgId, String title) async {
    try {
      final titleId = const Uuid().v4();

      // Create officer title locally
      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: titleId,
              orgId: orgId,
              title: title,
              createdAt: Value(DateTime.now()),
              clientUpdatedAt: Value(DateTime.now()),
            ),
          );

      // TODO: Sync to Supabase when RemoteOfficerTitleRepository is implemented

      return Result.success(titleId);
    } catch (e) {
      return Result.failure('Failed to create officer title: $e');
    }
  }

  /// Watch officer titles for an organization with member counts
  /// Requirements: 14.2
  Stream<List<OfficerTitleModel>> watchOfficerTitles(String orgId) {
    // Query officer titles for organization
    final query = db.select(db.officerTitles)
      ..where((tbl) => tbl.orgId.equals(orgId) & tbl.deleted.equals(false))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);

    return query.watch().asyncMap((titles) async {
      // For each title, count how many members have it
      final titleModels = <OfficerTitleModel>[];

      for (final title in titles) {
        // Count members with this officer title
        final countQuery = db.selectOnly(db.memberships)
          ..addColumns([db.memberships.id.count()])
          ..where(
            db.memberships.officerTitleId.equals(title.id) &
                db.memberships.deleted.equals(false) &
                db.memberships.status.equals('approved'),
          );

        final result = await countQuery.getSingle();
        final memberCount = result.read(db.memberships.id.count()) ?? 0;

        titleModels.add(OfficerTitleModel(
          id: title.id,
          orgId: title.orgId,
          title: title.title,
          memberCount: memberCount,
        ));
      }

      return titleModels;
    });
  }

  /// Assign an officer title to a member
  /// Requirements: 4.1, 4.3
  Future<Result<void>> assignOfficerTitle(
    String membershipId,
    String titleId,
  ) async {
    try {
      // Update membership with officer title ID
      await (db.update(db.memberships)
            ..where((tbl) => tbl.id.equals(membershipId)))
          .write(MembershipsCompanion(
        officerTitleId: Value(titleId),
        clientUpdatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ));

      // Note: Default officer permissions are applied through the permission
      // checking logic in PermissionRepository.hasPermission()
      // No need to explicitly copy permissions here

      // TODO: Sync to Supabase when RemoteOfficerTitleRepository is implemented

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to assign officer title: $e');
    }
  }

  /// Remove an officer title from a member
  /// Requirements: 4.4
  Future<Result<void>> removeOfficerTitle(String membershipId) async {
    try {
      // Clear officer title from membership
      await (db.update(db.memberships)
            ..where((tbl) => tbl.id.equals(membershipId)))
          .write(MembershipsCompanion(
        officerTitleId: const Value(null),
        clientUpdatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ));

      // Note: Permissions automatically revert to member permissions
      // through the permission checking logic in PermissionRepository.hasPermission()

      // TODO: Sync to Supabase when RemoteOfficerTitleRepository is implemented

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to remove officer title: $e');
    }
  }

  /// Update an officer title name
  Future<Result<void>> updateOfficerTitle(String titleId, String newTitle) async {
    try {
      await (db.update(db.officerTitles)
            ..where((tbl) => tbl.id.equals(titleId)))
          .write(OfficerTitlesCompanion(
        title: Value(newTitle),
        clientUpdatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ));

      // TODO: Sync to Supabase when RemoteOfficerTitleRepository is implemented

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to update officer title: $e');
    }
  }

  /// Delete an officer title (soft delete)
  Future<Result<void>> deleteOfficerTitle(String titleId) async {
    try {
      // Check if any members currently have this title
      final membersQuery = db.select(db.memberships)
        ..where((tbl) =>
            tbl.officerTitleId.equals(titleId) &
            tbl.deleted.equals(false) &
            tbl.status.equals('approved'));

      final membersWithTitle = await membersQuery.get();

      if (membersWithTitle.isNotEmpty) {
        return Result.failure(
          'Cannot delete officer title: ${membersWithTitle.length} member(s) currently have this title',
        );
      }

      // Soft delete the officer title
      await (db.update(db.officerTitles)
            ..where((tbl) => tbl.id.equals(titleId)))
          .write(OfficerTitlesCompanion(
        deleted: const Value(true),
        clientUpdatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ));

      // TODO: Sync to Supabase when RemoteOfficerTitleRepository is implemented

      return Result.success();
    } catch (e) {
      return Result.failure('Failed to delete officer title: $e');
    }
  }
}
