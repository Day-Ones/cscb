import 'package:flutter/material.dart';
import 'package:cscb_app/core/di/locator.dart';
import 'package:cscb_app/data/local/repositories/event_repository.dart';
import 'package:cscb_app/core/models/event_model.dart';
import 'package:cscb_app/core/services/permission_service.dart';
import 'package:cscb_app/screens/event_creation_page.dart';
import 'package:cscb_app/screens/event_detail_page.dart';

/// Page for listing all events (upcoming and past)
/// Requirements: 9.2, 9.3, 9.4
class EventListPage extends StatefulWidget {
  final String organizationId;
  final String organizationName;

  const EventListPage({
    super.key,
    required this.organizationId,
    required this.organizationName,
  });

  @override
  State<EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage>
    with SingleTickerProviderStateMixin {
  final _eventRepo = getIt<EventRepository>();
  final _permissionService = getIt<PermissionService>();

  late TabController _tabController;
  bool _canCreateEvents = false;
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final canCreate = await _permissionService.canCreateEvents(
      widget.organizationId,
    );

    setState(() {
      _canCreateEvents = canCreate;
      _isLoadingPermissions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.organizationName,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2196F3),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF2196F3),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEventList(isUpcoming: true),
          _buildEventList(isUpcoming: false),
        ],
      ),
      floatingActionButton: _isLoadingPermissions
          ? null
          : _canCreateEvents
              ? FloatingActionButton.extended(
                  onPressed: _navigateToCreateEvent,
                  backgroundColor: const Color(0xFF2196F3),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Create Event',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
    );
  }

  /// Build event list for upcoming or past events
  Widget _buildEventList({required bool isUpcoming}) {
    final stream = isUpcoming
        ? _eventRepo.watchUpcomingEvents(widget.organizationId)
        : _eventRepo.watchPastEvents(widget.organizationId);

    return StreamBuilder<List<EventModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2196F3)),
          );
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return _buildEmptyState(isUpcoming: isUpcoming);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            return _buildEventCard(events[index]);
          },
        );
      },
    );
  }

  /// Build empty state for when there are no events
  Widget _buildEmptyState({required bool isUpcoming}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUpcoming ? Icons.event_outlined : Icons.history_rounded,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isUpcoming ? 'No Upcoming Events' : 'No Past Events',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isUpcoming
                  ? 'Create an event to get started'
                  : 'Past events will appear here',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build a single event card
  Widget _buildEventCard(EventModel event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToEventDetail(event),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event name
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                // Date and time
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatEventDateTime(event.eventDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Location
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.location,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Show relative time for upcoming events
                if (event.isUpcoming) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          event.relativeTime,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Show description if available
                if (event.description != null &&
                    event.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    event.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Format event date and time for display
  String _formatEventDateTime(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year • $hour:$minute $period';
  }

  /// Navigate to event creation page
  Future<void> _navigateToCreateEvent() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EventCreationPage(
          organizationId: widget.organizationId,
          organizationName: widget.organizationName,
        ),
      ),
    );

    // Refresh is handled automatically by streams
    if (result == true && mounted) {
      // Event was created successfully
      // The stream will automatically update the list
    }
  }

  /// Navigate to event detail page
  void _navigateToEventDetail(EventModel event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventDetailPage(
          event: event,
          organizationId: widget.organizationId,
          organizationName: widget.organizationName,
        ),
      ),
    );
  }
}
