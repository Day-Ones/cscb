import 'package:drift/drift.dart';
import '../db/app_database.dart';

class UserProfileRepository {
  final AppDatabase _db;

  UserProfileRepository(this._db);

  /// Get user profile by user ID
  Future<UserProfile?> getUserProfileByUserId(String userId) async {
    return await (_db.select(_db.userProfiles)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.deleted.equals(false)))
        .getSingleOrNull();
  }

  /// Create a new user profile
  Future<UserProfile> createUserProfile(UserProfilesCompanion profile) async {
    await _db.into(_db.userProfiles).insert(profile);
    return (await (_db.select(_db.userProfiles)
              ..where((tbl) => tbl.id.equals(profile.id.value)))
            .getSingle());
  }

  /// Update user profile
  Future<bool> updateUserProfile(UserProfile profile) async {
    return await _db.update(_db.userProfiles).replace(profile);
  }

  /// Delete user profile (soft delete)
  Future<void> deleteUserProfile(String id) async {
    await (_db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(id)))
        .write(const UserProfilesCompanion(deleted: Value(true)));
  }
}
