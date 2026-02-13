import 'package:get_it/get_it.dart';
import '../../data/local/db/app_database.dart';
import '../../data/local/repositories/org_repository.dart';
import '../../data/local/repositories/user_repository.dart';
import '../../data/local/repositories/user_profile_repository.dart';
import '../../data/local/repositories/event_repository.dart';
import '../../data/local/repositories/permission_repository.dart';
import '../../data/local/repositories/officer_title_repository.dart';
import '../../data/local/services/auth_service_with_remote.dart';
import '../../data/local/services/permission_migration_service.dart';
import '../../data/remote/repositories/remote_user_repository.dart';
import '../../data/remote/repositories/remote_org_repository.dart';
import '../../data/remote/repositories/remote_membership_repository.dart';
import '../../data/remote/repositories/remote_event_repository.dart';
import '../../data/remote/repositories/remote_attendance_repository.dart';
import '../../data/sync/sync_service.dart';
import '../../data/sync/auto_sync_manager.dart';
import '../session/user_session.dart';
import '../services/permission_service.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  // 1. Initialize Database
  final db = AppDatabase();

  // 2. Register Singletons
  getIt.registerSingleton<AppDatabase>(db);
  getIt.registerSingleton<UserSession>(UserSession());

  // 3. Register Remote Repositories
  getIt.registerSingleton<RemoteUserRepository>(RemoteUserRepository());
  getIt.registerSingleton<RemoteOrgRepository>(RemoteOrgRepository());
  getIt.registerSingleton<RemoteMembershipRepository>(RemoteMembershipRepository());
  getIt.registerSingleton<RemoteEventRepository>(RemoteEventRepository());
  getIt.registerSingleton<RemoteAttendanceRepository>(RemoteAttendanceRepository());

  // 4. Register Local Repositories with remote support
  getIt.registerSingleton<PermissionRepository>(
    PermissionRepository(db, getIt<UserSession>()),
  );
  
  getIt.registerSingleton<OrgRepository>(
    OrgRepository(
      db,
      getIt<UserSession>(),
      getIt<RemoteOrgRepository>(),
      getIt<RemoteMembershipRepository>(),
      getIt<PermissionRepository>(),
    ),
  );
  getIt.registerSingleton<UserRepository>(UserRepository(db));
  getIt.registerSingleton<UserProfileRepository>(UserProfileRepository(db));
  getIt.registerSingleton<EventRepository>(
    EventRepository(db, getIt<UserSession>()),
  );
  getIt.registerSingleton<OfficerTitleRepository>(
    OfficerTitleRepository(db),
  );

  // 5. Register Services with remote support
  final authService = AuthServiceWithRemote(
    getIt<UserRepository>(),
    getIt<RemoteUserRepository>(),
  );
  getIt.registerSingleton<AuthServiceWithRemote>(authService);

  // Register PermissionService
  getIt.registerSingleton<PermissionService>(
    PermissionService(db, getIt<UserSession>()),
  );

  // Register PermissionMigrationService
  getIt.registerSingleton<PermissionMigrationService>(
    PermissionMigrationService(db, getIt<PermissionRepository>()),
  );

  // Register SyncService
  getIt.registerSingleton<SyncService>(
    SyncService(
      db,
      getIt<RemoteUserRepository>(),
      getIt<RemoteOrgRepository>(),
      getIt<RemoteEventRepository>(),
      getIt<RemoteAttendanceRepository>(),
    ),
  );

  // Register AutoSyncManager
  getIt.registerSingleton<AutoSyncManager>(
    AutoSyncManager(getIt<SyncService>()),
  );

  // Note: Users are now managed in Supabase database
  // Run the seed_users.sql script in Supabase to create initial users
}
