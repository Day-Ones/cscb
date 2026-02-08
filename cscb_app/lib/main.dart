import 'package:flutter/material.dart';
import 'core/di/locator.dart';
import 'data/remote/supabase_service.dart';
import 'data/local/services/permission_migration_service.dart';
import 'screens/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize Database and Repo
  await setupLocator();

  // Run permission migration for existing organizations
  final migrationService = getIt<PermissionMigrationService>();
  await migrationService.initializePermissionsForExistingOrganizations();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSCB App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          primary: Colors.lightBlue,
          surface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
