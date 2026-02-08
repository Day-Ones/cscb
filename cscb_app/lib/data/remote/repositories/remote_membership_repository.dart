import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

class RemoteMembershipRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Fetch all memberships from Supabase
  Future<List<Map<String, dynamic>>> getAllMemberships() async {
    try {
      final response = await _supabase
          .from('memberships')
          .select()
          .eq('deleted', false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch memberships: $e');
    }
  }

  /// Get memberships by organization ID
  Future<List<Map<String, dynamic>>> getMembershipsByOrg(String orgId) async {
    try {
      final response = await _supabase
          .from('memberships')
          .select()
          .eq('org_id', orgId)
          .eq('deleted', false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch memberships: $e');
    }
  }

  /// Create membership in Supabase
  Future<void> createMembership(Map<String, dynamic> membership) async {
    try {
      await _supabase.from('memberships').insert(membership);
    } catch (e) {
      throw Exception('Failed to create membership: $e');
    }
  }

  /// Update membership in Supabase
  Future<void> updateMembership(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('memberships')
          .update(updates)
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update membership: $e');
    }
  }

  /// Delete membership (soft delete)
  Future<void> deleteMembership(String id) async {
    try {
      await _supabase
          .from('memberships')
          .update({'deleted': true})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete membership: $e');
    }
  }
}
