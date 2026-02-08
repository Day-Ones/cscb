import 'package:drift/drift.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';

/// Service to handle permission migrations for existing organizations
/// Requirements: 6.1
class PermissionMigrationService {
  final AppDatabase db;
  final PermissionRepository permissionRepository;

  PermissionMigrationService(this.db, this.permissionRepository);

  /// Initialize default permissions for all existing organizations
  /// This should be run once on app startup to ensure all organizations have permissions
  /// Requirements: 6.1
  Future<void> initializePermissionsForExistingOrganizations() async {
    try {
      // Get all organizations
      final organizations = await (db.select(db.organizations)
            ..where((tbl) => tbl.deleted.equals(false)))
          .get();

      print('Found ${organizations.length} organizations to check for permissions');

      for (final org in organizations) {
        // Check if organization already has permissions initialized
        final existingPermissions = await (db.select(db.organizationPermissions)
              ..where((tbl) => tbl.orgId.equals(org.id) & tbl.deleted.equals(false)))
            .get();

        if (existingPermissions.isEmpty) {
          print('Initializing permissions for organization: ${org.name} (${org.id})');
          await permissionRepository.initializeDefaultPermissions(org.id);
        } else {
          print('Organization ${org.name} already has ${existingPermissions.length} permissions');
        }
      }

      print('Permission initialization complete');
    } catch (e) {
      print('Error initializing permissions for existing organizations: $e');
      // Don't throw - we want the app to continue even if migration fails
    }
  }
}
