import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

class RemoteEventRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Create event in Supabase
  Future<void> createEvent(Map<String, dynamic> event) async {
    try {
      await _supabase.from('events').insert(event);
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  /// Update event in Supabase
  Future<void> updateEvent(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('events')
          .update(updates)
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  /// Delete event (soft delete) in Supabase
  Future<void> deleteEvent(String id) async {
    try {
      await _supabase
          .from('events')
          .update({'deleted': true})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  /// Get all events from Supabase
  Future<List<Map<String, dynamic>>> getAllEvents() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .eq('deleted', false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch events: $e');
    }
  }
}
