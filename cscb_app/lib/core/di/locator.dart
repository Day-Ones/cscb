import 'package:get_it/get_it.dart';
import '../../data/local/db/app_database.dart';
import '../../data/local/repositories/org_repository.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  // 1. Initialize Database
  final db = AppDatabase();

  // 2. Register Singletons
  getIt.registerSingleton<AppDatabase>(db);

  // 3. Register Repository
  getIt.registerSingleton<OrgRepository>(OrgRepository(db));
}
