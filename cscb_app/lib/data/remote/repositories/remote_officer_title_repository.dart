import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

class RemoteOfficerTitleRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Create officer title in Supabase
  Future<void> createOfficerTitle(Map<String, dynamic> officerTitle) async {
    try {
      await _supabase.from('officer_titles').insert(officerTitle);
    } catch (e) {
      throw Exception('Failed to create officer title: $e');
    }
  }

  /// Assign officer title to member in Supabase
  Future<void> assignOfficerTitle(
    String membershipId,
    String officerTitleId,
  ) async {
    try {
      await _supabase
          .from('memberships')
          .update({'officer_title_id': officerTitleId})
          .eq('id', membershipId);
    } catch (e) {
      throw Exception('Failed to assign officer title: $e');
    }
  }

  /// Remove officer title from member in Supabase
  Future<void> removeOfficerTitle(String membershipId) async {
    try {
      await _supabase
          .from('memberships')
          .update({'officer_title_id': null})
          .eq('id', membershipId);
    } catch (e) {
      throw Exception('Failed to remove officer title: $e');
    }
  }

  /// Get all officer titles for an organization from Supabase
  Future<List<Map<String, dynamic>>> getOfficerTitles(String orgId) async {
    try {
      final response = await _supabase
          .from('officer_titles')
          .select()
          .eq('org_id', orgId)
          .eq('deleted', false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch officer titles: $e');
    }
  }
}
