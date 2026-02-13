import 'package:flutter/material.dart';
import 'core/di/locator.dart';
import 'data/remote/supabase_service.dart';
import 'data/sync/auto_sync_manager.dart';
import 'screens/events_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize Database and Repo
  await setupLocator();

  // Start automatic sync manager
  final autoSyncManager = getIt<AutoSyncManager>();
  await autoSyncManager.start();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event Attendance Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          primary: Colors.lightBlue,
          surface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const EventsHomePage(),
    );
  }
}
