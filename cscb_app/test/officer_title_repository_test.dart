import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/local/repositories/officer_title_repository.dart';

void main() {
  late AppDatabase db;
  late OfficerTitleRepository repository;

  setUp(() {
    // Create in-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = OfficerTitleRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('OfficerTitleRepository', () {
    test('createOfficerTitle creates a new officer title', () async {
      // Create a test organization first
      final orgId = 'test-org-id';
      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Organization',
            ),
          );

      // Create officer title
      final result = await repository.createOfficerTitle(orgId, 'Vice President');

      expect(result.success, true);
      expect(result.data, isNotNull);

      // Verify it was created
      final titles = await (db.select(db.officerTitles)
            ..where((tbl) => tbl.orgId.equals(orgId)))
          .get();

      expect(titles.length, 1);
      expect(titles.first.title, 'Vice President');
      expect(titles.first.orgId, orgId);
    });

    test('watchOfficerTitles returns stream of officer titles with member counts', () async {
      // Create a test organization
      final orgId = 'test-org-id';
      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Organization',
            ),
          );

      // Create officer titles
      final titleId1 = 'title-1';
      final titleId2 = 'title-2';
      
      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: titleId1,
              orgId: orgId,
              title: 'Vice President',
            ),
          );
      
      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: titleId2,
              orgId: orgId,
              title: 'Secretary',
            ),
          );

      // Create a user and membership with officer title
      final userId = 'user-1';
      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test User',
              email: 'test@example.com',
              passwordHash: 'hash',
            ),
          );

      final membershipId = 'membership-1';
      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: userId,
              orgId: orgId,
              role: 'officer',
              status: const drift.Value('approved'),
              officerTitleId: drift.Value(titleId1),
            ),
          );

      // Watch officer titles
      final stream = repository.watchOfficerTitles(orgId);
      final titles = await stream.first;

      expect(titles.length, 2);
      
      // Find the Vice President title
      final vpTitle = titles.firstWhere((t) => t.title == 'Vice President');
      expect(vpTitle.memberCount, 1);
      
      // Find the Secretary title
      final secTitle = titles.firstWhere((t) => t.title == 'Secretary');
      expect(secTitle.memberCount, 0);
    });

    test('assignOfficerTitle updates membership with officer title', () async {
      // Create test data
      final orgId = 'test-org-id';
      final userId = 'user-1';
      final membershipId = 'membership-1';
      final titleId = 'title-1';

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Organization',
            ),
          );

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test User',
              email: 'test@example.com',
              passwordHash: 'hash',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: userId,
              orgId: orgId,
              role: 'member',
            ),
          );

      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: titleId,
              orgId: orgId,
              title: 'Vice President',
            ),
          );

      // Assign officer title
      final result = await repository.assignOfficerTitle(membershipId, titleId);

      expect(result.success, true);

      // Verify assignment
      final membership = await (db.select(db.memberships)
            ..where((tbl) => tbl.id.equals(membershipId)))
          .getSingle();

      expect(membership.officerTitleId, titleId);
    });

    test('removeOfficerTitle clears officer title from membership', () async {
      // Create test data with officer title assigned
      final orgId = 'test-org-id';
      final userId = 'user-1';
      final membershipId = 'membership-1';
      final titleId = 'title-1';

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Organization',
            ),
          );

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test User',
              email: 'test@example.com',
              passwordHash: 'hash',
            ),
          );

      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: titleId,
              orgId: orgId,
              title: 'Vice President',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: userId,
              orgId: orgId,
              role: 'officer',
              officerTitleId: drift.Value(titleId),
            ),
          );

      // Remove officer title
      final result = await repository.removeOfficerTitle(membershipId);

      expect(result.success, true);

      // Verify removal
      final membership = await (db.select(db.memberships)
            ..where((tbl) => tbl.id.equals(membershipId)))
          .getSingle();

      expect(membership.officerTitleId, isNull);
    });

    test('deleteOfficerTitle prevents deletion when members have the title', () async {
      // Create test data with member having the title
      final orgId = 'test-org-id';
      final userId = 'user-1';
      final membershipId = 'membership-1';
      final titleId = 'title-1';

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Organization',
            ),
          );

      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: userId,
              name: 'Test User',
              email: 'test@example.com',
              passwordHash: 'hash',
            ),
          );

      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: titleId,
              orgId: orgId,
              title: 'Vice President',
            ),
          );

      await db.into(db.memberships).insert(
            MembershipsCompanion.insert(
              id: membershipId,
              userId: userId,
              orgId: orgId,
              role: 'officer',
              status: const drift.Value('approved'),
              officerTitleId: drift.Value(titleId),
            ),
          );

      // Try to delete officer title
      final result = await repository.deleteOfficerTitle(titleId);

      expect(result.success, false);
      expect(result.errorMessage, contains('Cannot delete officer title'));
    });

    test('deleteOfficerTitle succeeds when no members have the title', () async {
      // Create test data without members having the title
      final orgId = 'test-org-id';
      final titleId = 'title-1';

      await db.into(db.organizations).insert(
            OrganizationsCompanion.insert(
              id: orgId,
              name: 'Test Organization',
            ),
          );

      await db.into(db.officerTitles).insert(
            OfficerTitlesCompanion.insert(
              id: titleId,
              orgId: orgId,
              title: 'Vice President',
            ),
          );

      // Delete officer title
      final result = await repository.deleteOfficerTitle(titleId);

      expect(result.success, true);

      // Verify soft delete
      final title = await (db.select(db.officerTitles)
            ..where((tbl) => tbl.id.equals(titleId)))
          .getSingle();

      expect(title.deleted, true);
    });
  });
}
