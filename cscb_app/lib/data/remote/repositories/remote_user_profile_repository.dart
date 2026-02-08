import '../supabase_service.dart';

class RemoteUserProfileRepository {
  final _supabase = SupabaseService.client;

  /// Get user profile by user ID from Supabase
  Future<Map<String, dynamic>?> getUserProfileByUserId(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .eq('deleted', false)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching user profile from Supabase: $e');
      return null;
    }
  }

  /// Create user profile in Supabase
  Future<void> createUserProfile(Map<String, dynamic> profile) async {
    try {
      await _supabase.from('user_profiles').insert(profile);
    } catch (e) {
      print('Error creating user profile in Supabase: $e');
      rethrow;
    }
  }

  /// Update user profile in Supabase
  Future<void> updateUserProfile(String id, Map<String, dynamic> profile) async {
    try {
      await _supabase
          .from('user_profiles')
          .update(profile)
          .eq('id', id);
    } catch (e) {
      print('Error updating user profile in Supabase: $e');
      rethrow;
    }
  }

  /// Delete user profile in Supabase (soft delete)
  Future<void> deleteUserProfile(String id) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({'deleted': true})
          .eq('id', id);
    } catch (e) {
      print('Error deleting user profile in Supabase: $e');
      rethrow;
    }
  }
}
