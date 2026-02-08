import 'package:drift/drift.dart';
import '../db/app_database.dart';

class UserRepository {
  final AppDatabase _database;

  UserRepository(this._database);

  /// Get user by email (including password hash and role)
  Future<User?> getUserByEmail(String email) async {
    try {
      final query = _database.select(_database.users)
        ..where((tbl) => tbl.email.equals(email) & tbl.deleted.equals(false));
      
      final results = await query.get();
      return results.isEmpty ? null : results.first;
    } catch (e) {
      return null;
    }
  }

  /// Create new user
  Future<void> createUser(UsersCompanion user) async {
    await _database.into(_database.users).insert(user);
  }

  /// Check if user exists by email
  Future<bool> userExists(String email) async {
    final query = _database.select(_database.users)
      ..where((tbl) => tbl.email.equals(email));
    
    final results = await query.get();
    return results.isNotEmpty;
  }
}
