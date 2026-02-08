import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

class RemoteOrgRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Fetch all organizations from Supabase
  Future<List<Map<String, dynamic>>> getAllOrganizations() async {
    try {
      final response = await _supabase
          .from('organizations')
          .select()
          .eq('deleted', false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch organizations: $e');
    }
  }

  /// Get organizations by status
  Future<List<Map<String, dynamic>>> getOrganizationsByStatus(String status) async {
    try {
      final response = await _supabase
          .from('organizations')
          .select()
          .eq('status', status)
          .eq('deleted', false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch organizations: $e');
    }
  }

  /// Create organization in Supabase
  Future<void> createOrganization(Map<String, dynamic> org) async {
    try {
      await _supabase.from('organizations').insert(org);
    } catch (e) {
      throw Exception('Failed to create organization: $e');
    }
  }

  /// Update organization in Supabase
  Future<void> updateOrganization(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('organizations')
          .update(updates)
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update organization: $e');
    }
  }

  /// Approve organization
  Future<void> approveOrganization(String id) async {
    await updateOrganization(id, {'status': 'active'});
  }

  /// Suspend organization
  Future<void> suspendOrganization(String id) async {
    await updateOrganization(id, {'status': 'suspended'});
  }

  /// Delete organization (soft delete)
  Future<void> deleteOrganization(String id) async {
    try {
      await _supabase
          .from('organizations')
          .update({'deleted': true})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete organization: $e');
    }
  }
}
