import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

class RemotePermissionRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Update organization permissions in Supabase
  Future<void> updateOrganizationPermissions(
    String orgId,
    List<Map<String, dynamic>> permissions,
  ) async {
    try {
      // Delete existing permissions for this organization
      await _supabase
          .from('organization_permissions')
          .delete()
          .eq('org_id', orgId);

      // Insert new permissions
      if (permissions.isNotEmpty) {
        await _supabase.from('organization_permissions').insert(permissions);
      }
    } catch (e) {
      throw Exception('Failed to update organization permissions: $e');
    }
  }

  /// Update member permissions in Supabase
  Future<void> updateMemberPermissions(
    String membershipId,
    List<Map<String, dynamic>> permissions,
  ) async {
    try {
      // Delete existing permissions for this member
      await _supabase
          .from('member_permissions')
          .delete()
          .eq('membership_id', membershipId);

      // Insert new permissions
      if (permissions.isNotEmpty) {
        await _supabase.from('member_permissions').insert(permissions);
      }
    } catch (e) {
      throw Exception('Failed to update member permissions: $e');
    }
  }

  /// Get organization permissions from Supabase
  Future<List<Map<String, dynamic>>> getOrganizationPermissions(
    String orgId,
  ) async {
    try {
      final response = await _supabase
          .from('organization_permissions')
          .select()
          .eq('org_id', orgId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch organization permissions: $e');
    }
  }

  /// Get member permissions from Supabase
  Future<List<Map<String, dynamic>>> getMemberPermissions(
    String membershipId,
  ) async {
    try {
      final response = await _supabase
          .from('member_permissions')
          .select()
          .eq('membership_id', membershipId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch member permissions: $e');
    }
  }
}
