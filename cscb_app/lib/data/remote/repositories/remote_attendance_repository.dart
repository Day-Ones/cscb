import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';

class RemoteAttendanceRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  /// Create attendance record in Supabase
  Future<void> createAttendance(Map<String, dynamic> attendance) async {
    try {
      await _supabase.from('attendance').insert(attendance);
    } catch (e) {
      throw Exception('Failed to create attendance: $e');
    }
  }

  /// Update attendance record in Supabase
  Future<void> updateAttendance(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('attendance')
          .update(updates)
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update attendance: $e');
    }
  }

  /// Delete attendance (soft delete) in Supabase
  Future<void> deleteAttendance(String id) async {
    try {
      await _supabase
          .from('attendance')
          .update({'deleted': true})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete attendance: $e');
    }
  }

  /// Get all attendance for an event from Supabase
  Future<List<Map<String, dynamic>>> getEventAttendance(String eventId) async {
    try {
      final response = await _supabase
          .from('attendance')
          .select()
          .eq('event_id', eventId)
          .eq('deleted', false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch attendance: $e');
    }
  }

  /// Get attendance by event and student number (for duplicate checking)
  Future<Map<String, dynamic>?> getAttendanceByEventAndStudent(
    String eventId,
    String studentNumber,
  ) async {
    try {
      final response = await _supabase
          .from('attendance')
          .select()
          .eq('event_id', eventId)
          .eq('student_number', studentNumber)
          .eq('deleted', false)
          .maybeSingle();
      return response;
    } catch (e) {
      throw Exception('Failed to fetch attendance: $e');
    }
  }

  /// Get all attendance records from Supabase
  Future<List<Map<String, dynamic>>> getAllAttendance() async {
    try {
      final response = await _supabase
          .from('attendance')
          .select()
          .eq('deleted', false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch all attendance: $e');
    }
  }
}
