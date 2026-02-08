import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:cscb_app/core/di/locator.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/core/models/event_model.dart';
import 'package:cscb_app/core/models/membership_with_user.dart';
import 'package:cscb_app/data/local/repositories/event_repository.dart';
import 'package:cscb_app/data/local/repositories/org_repository.dart';
import 'package:cscb_app/core/services/permission_service.dart';
import 'package:cscb_app/screens/event_creation_page.dart';
import 'package:cscb_app/screens/event_list_page.dart';
import 'package:cscb_app/screens/event_detail_page.dart';
import 'package:cscb_app/screens/permission_settings_page.dart';

/// Dashboard page for an organization
/// Requirements: 1.1
class OrganizationDashboardPage extends StatefulWidget {
  final String organizationId;
  final String organizationName;

  const OrganizationDashboardPage({
    super.key,
    required this.organizationId,
    required this.organizationName,
  });

  @override
  State<OrganizationDashboardPage> createState() =>
      _OrganizationDashboardPageState();
}

class _OrganizationDashboardPageState
    extends State<OrganizationDashboardPage> {
  final _eventRepo = getIt<EventRepository>();
  final _orgRepo = getIt<OrgRepository>();
  final _permissionService = getIt<PermissionService>();
  final _userSession = getIt<UserSession>();

  bool _isPresident = false;
  bool _canCreateEvents = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    if (!_userSession.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    final userId = _userSession.userId!;

    // Check if user is president
    final membershipQuery = _orgRepo.db.select(_orgRepo.db.memberships)
      ..where((tbl) =>
          (tbl.userId.equals(userId) &
          tbl.orgId.equals(widget.organizationId)) &
          tbl.status.equals('approved'));

    final membership = await membershipQuery.getSingleOrNull();

    final isPresident = membership?.role == 'president';

    // Check if user can create events
    final canCreateEvents = await _permissionService.canCreateEvents(
      widget.organizationId,
    );

    setState(() {
      _isPresident = isPresident;
      _canCreateEvents = canCreateEvents;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2196F3)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _isPresident
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                widget.organizationName,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                // Permission settings menu item (president only)
                // Requirements: 11.1
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  onSelected: (value) {
                    if (value == 'permissions') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PermissionSettingsPage(
                            organizationId: widget.organizationId,
                            organizationName: widget.organizationName,
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'permissions',
                      child: Row(
                        children: [
                          Icon(Icons.security_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Permission Settings'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics cards section
            _buildStatisticsSection(),
            const SizedBox(height: 20),
            // Upcoming event card
            _buildUpcomingEventSection(),
            const SizedBox(height: 20),
            // Quick action buttons
            _buildQuickActionsSection(),
          ],
        ),
      ),
    );
  }

  /// Build statistics cards section
  /// Requirements: 1.2, 1.3, 1.4, 8.1, 8.2, 8.3
  Widget _buildStatisticsSection() {
    return StreamBuilder<List<MembershipWithUser>>(
      stream: _orgRepo.watchOrganizationMembers(widget.organizationId),
      builder: (context, memberSnapshot) {
        final memberCount = memberSnapshot.data?.length ?? 0;

        return FutureBuilder<Map<String, int>>(
          future: _getEventCounts(),
          builder: (context, eventSnapshot) {
            final upcomingCount = eventSnapshot.data?['upcoming'] ?? 0;
            final pastCount = eventSnapshot.data?['past'] ?? 0;

            return LayoutBuilder(
              builder: (context, constraints) {
                // Use grid layout for statistics cards
                final isWide = constraints.maxWidth > 600;
                
                return isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.people_rounded,
                              iconColor: Colors.blue,
                              count: memberCount,
                              label: 'Members',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.event_rounded,
                              iconColor: Colors.green,
                              count: upcomingCount,
                              label: 'Upcoming Events',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.history_rounded,
                              iconColor: Colors.orange,
                              count: pastCount,
                              label: 'Past Events',
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildStatCard(
                            icon: Icons.people_rounded,
                            iconColor: Colors.blue,
                            count: memberCount,
                            label: 'Members',
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            icon: Icons.event_rounded,
                            iconColor: Colors.green,
                            count: upcomingCount,
                            label: 'Upcoming Events',
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard(
                            icon: Icons.history_rounded,
                            iconColor: Colors.orange,
                            count: pastCount,
                            label: 'Past Events',
                          ),
                        ],
                      );
              },
            );
          },
        );
      },
    );
  }

  /// Get event counts for statistics
  Future<Map<String, int>> _getEventCounts() async {
    final upcomingCount = await _eventRepo.getUpcomingEventCount(
      widget.organizationId,
    );
    final pastCount = await _eventRepo.getPastEventCount(
      widget.organizationId,
    );

    return {
      'upcoming': upcomingCount,
      'past': pastCount,
    };
  }

  /// Build a single statistics card
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required int count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          // Icon with colored background
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          // Count
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build upcoming event section
  /// Requirements: 1.5, 2.1, 2.2, 2.3, 2.4, 2.5, 8.4
  Widget _buildUpcomingEventSection() {
    return StreamBuilder<List<EventModel>>(
      stream: _eventRepo.watchUpcomingEvents(widget.organizationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 180,
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
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF2196F3)),
            ),
          );
        }

        final events = snapshot.data ?? [];
        final event = events.isNotEmpty ? events.first : null;

        // Handle empty state
        if (event == null) {
          return Container(
            padding: const EdgeInsets.all(32),
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
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Upcoming Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create an event to get started',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Show event card with tap navigation
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // Navigate to event details page
              // Requirements: 2.5
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventDetailPage(
                    event: event,
                    organizationId: widget.organizationId,
                    organizationName: widget.organizationName,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Next Event',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Event name
                  Text(
                    event.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date and time
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatEventDateTime(event.eventDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Countdown/relative time
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event.relativeTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  /// Build quick action buttons section
  /// Requirements: 1.7, 3.1, 9.1, 10.1
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Create Event button (permission-based)
        if (_canCreateEvents)
          _buildActionButton(
            icon: Icons.add_circle_rounded,
            label: 'Create Event',
            color: const Color(0xFF2196F3),
            onTap: () {
              // Navigate to event creation page
              // Requirements: 3.1
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventCreationPage(
                    organizationId: widget.organizationId,
                    organizationName: widget.organizationName,
                  ),
                ),
              );
            },
          ),
        if (_canCreateEvents) const SizedBox(height: 12),
        
        // Manage Members button (president only)
        if (_isPresident)
          _buildActionButton(
            icon: Icons.people_rounded,
            label: 'Manage Members',
            color: const Color(0xFF4CAF50),
            onTap: () {
              // TODO: Navigate to member management page
              // Requirements: 10.1
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Member management page coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        if (_isPresident) const SizedBox(height: 12),
        
        // View All Events button
        _buildActionButton(
          icon: Icons.event_note_rounded,
          label: 'View All Events',
          color: const Color(0xFFFF9800),
          onTap: () {
            // Navigate to events list page
            // Requirements: 9.1
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EventListPage(
                  organizationId: widget.organizationId,
                  organizationName: widget.organizationName,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Build a single action button
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
