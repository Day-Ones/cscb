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

  /// Get user profile by Google ID
  Future<UserProfile?> getProfileByGoogleId(String googleId) async {
    return await (_db.select(_db.userProfiles)
          ..where((tbl) => tbl.googleId.equals(googleId) & tbl.deleted.equals(false)))
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

  /// Update user profile by ID with companion
  Future<bool> updateProfileById(String id, UserProfilesCompanion profile) async {
    return await (_db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(id)))
        .write(profile) > 0;
  }

  /// Check if profile is complete
  Future<bool> isProfileComplete(String userId) async {
    final profile = await getUserProfileByUserId(userId);
    if (profile == null) return false;
    
    return profile.isComplete &&
           profile.studentNumber != null &&
           profile.firstName != null &&
           profile.lastName != null &&
           profile.program != null &&
           profile.yearLevel != null &&
           profile.section != null;
  }

  /// Delete user profile (soft delete)
  Future<void> deleteUserProfile(String id) async {
    await (_db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(id)))
        .write(const UserProfilesCompanion(deleted: Value(true)));
  }

  /// Get all user profiles (for admin)
  Future<List<UserProfile>> getAllProfiles() async {
    return await (_db.select(_db.userProfiles)
          ..where((tbl) => tbl.deleted.equals(false)))
        .get();
  }
}
