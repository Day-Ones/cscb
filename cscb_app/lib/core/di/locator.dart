import 'package:get_it/get_it.dart';
import '../../data/local/db/app_database.dart';
import '../../data/local/repositories/org_repository.dart';
import '../../data/local/repositories/user_repository.dart';
import '../../data/local/services/auth_service_with_remote.dart';
import '../../data/remote/repositories/remote_user_repository.dart';
import '../../data/remote/repositories/remote_org_repository.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  // 1. Initialize Database
  final db = AppDatabase();

  // 2. Register Singletons
  getIt.registerSingleton<AppDatabase>(db);

  // 3. Register Remote Repositories
  getIt.registerSingleton<RemoteUserRepository>(RemoteUserRepository());
  getIt.registerSingleton<RemoteOrgRepository>(RemoteOrgRepository());

  // 4. Register Local Repositories with remote support
  getIt.registerSingleton<OrgRepository>(
    OrgRepository(db, getIt<RemoteOrgRepository>()),
  );
  getIt.registerSingleton<UserRepository>(UserRepository(db));

  // 5. Register Services with remote support
  final authService = AuthServiceWithRemote(
    getIt<UserRepository>(),
    getIt<RemoteUserRepository>(),
  );
  getIt.registerSingleton<AuthServiceWithRemote>(authService);

  // Note: Users are now managed in Supabase database
  // Run the seed_users.sql script in Supabase to create initial users
}
