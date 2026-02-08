import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

class RemoteUserRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Fetch all users from Supabase
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('deleted', false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  /// Get user by email from Supabase
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('email', email)
          .eq('deleted', false)
          .maybeSingle();
      return response;
    } catch (e) {
      throw Exception('Failed to fetch user: $e');
    }
  }

  /// Create user in Supabase
  Future<void> createUser(Map<String, dynamic> user) async {
    try {
      await _supabase.from('users').insert(user);
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  /// Update user in Supabase
  Future<void> updateUser(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('users')
          .update(updates)
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  /// Delete user (soft delete) in Supabase
  Future<void> deleteUser(String id) async {
    try {
      await _supabase
          .from('users')
          .update({'deleted': true})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
}
