import 'package:cscb_app/data/local/db/app_database.dart';

/// Model representing an event with computed properties
class EventModel {
  final String id;
  final String orgId;
  final String name;
  final String? description;
  final DateTime eventDate;
  final String location;
  final int? maxAttendees;
  final String createdBy;
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.orgId,
    required this.name,
    this.description,
    required this.eventDate,
    required this.location,
    this.maxAttendees,
    required this.createdBy,
    required this.createdAt,
  });

  /// Create EventModel from database Event
  factory EventModel.fromEvent(Event event) {
    return EventModel(
      id: event.id,
      orgId: event.orgId,
      name: event.name,
      description: event.description,
      eventDate: event.eventDate,
      location: event.location,
      maxAttendees: event.maxAttendees,
      createdBy: event.createdBy,
      createdAt: event.createdAt,
    );
  }

  /// Check if event is in the future
  bool get isUpcoming => eventDate.isAfter(DateTime.now());

  /// Check if event is in the past
  bool get isPast => eventDate.isBefore(DateTime.now());

  /// Get relative time string for countdown display
  String get relativeTime {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    if (difference.inDays > 0) {
      return 'in ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return 'in ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else if (difference.inSeconds > 0) {
      return 'in ${difference.inSeconds} second${difference.inSeconds == 1 ? '' : 's'}';
    } else {
      return 'now';
    }
  }
}
