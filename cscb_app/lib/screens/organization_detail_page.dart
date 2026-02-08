import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:cscb_app/core/di/locator.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/core/models/membership_with_user.dart';
import 'package:cscb_app/core/models/officer_title_model.dart';
import 'package:cscb_app/core/models/permission.dart';
import 'package:cscb_app/core/models/permission_model.dart';
import 'package:cscb_app/data/local/repositories/org_repository.dart';
import 'package:cscb_app/data/local/repositories/officer_title_repository.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';
import 'package:cscb_app/screens/organization_dashboard_page.dart';
import 'package:cscb_app/screens/event_list_page.dart';
import 'package:cscb_app/core/services/permission_service.dart';

class OrganizationDetailPage extends StatefulWidget {
  final String organizationId;
  final String organizationName;

  const OrganizationDetailPage({
    super.key,
    required this.organizationId,
    required this.organizationName,
  });

  @override
  State<OrganizationDetailPage> createState() => _OrganizationDetailPageState();
}

class _OrganizationDetailPageState extends State<OrganizationDetailPage>
    with SingleTickerProviderStateMixin {
  final _orgRepo = getIt<OrgRepository>();
  final _userSession = getIt<UserSession>();
  final _permissionService = getIt<PermissionService>();
  
  late TabController _tabController;
  bool _isPresident = false;
  bool _canManageMembers = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkUserRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    if (!_userSession.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    final userId = _userSession.userId!;
    
    final membership = await (_orgRepo.db.select(_orgRepo.db.memberships)
          ..where((tbl) =>
              tbl.userId.equals(userId) &
              tbl.orgId.equals(widget.organizationId) &
              tbl.status.equals('approved')))
        .getSingleOrNull();

    final isPresident = membership?.role == 'president';
    
    // Check if user can manage members
    final canManageMembers = await _permissionService.canManageMembers(
      widget.organizationId,
    );

    setState(() {
      _isPresident = isPresident;
      _canManageMembers = canManageMembers;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF2196F3),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.organizationName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              ),
              actions: [
                if (!_isPresident)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'leave') {
                        _leaveOrganization();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app_rounded, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text(
                              'Leave Organization',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF2196F3),
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: const Color(0xFF2196F3),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    tabs: [
                      const Tab(text: 'DASHBOARD'),
                      const Tab(text: 'EVENTS'),
                      if (_canManageMembers)
                        const Tab(text: 'MEMBERS')
                      else
                        const Tab(text: 'MEMBERS'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Dashboard tab
            OrganizationDashboardPage(
              organizationId: widget.organizationId,
              organizationName: widget.organizationName,
            ),
            // Events tab
            EventListPage(
              organizationId: widget.organizationId,
              organizationName: widget.organizationName,
            ),
            // Members tab
            _canManageMembers && _isPresident
                ? _PresidentMembersView(
                    orgId: widget.organizationId,
                    onTransferPresidency: _transferPresidency,
                    onRemoveMember: _removeMember,
                    onApproveMembership: _approveMembership,
                    onRejectMembership: _rejectMembership,
                  )
                : _MembersTabView(
                    orgId: widget.organizationId,
                    isPresident: _isPresident,
                    onTransferPresidency: _transferPresidency,
                    onRemoveMember: _removeMember,
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveMembership(MembershipWithUser memberWithUser) async {
    // Check permission before executing action
    // Requirements: 7.1, 7.3
    if (!_canManageMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.block, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('You don\'t have permission to manage members'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final result = await _orgRepo.approveMembership(memberWithUser.membership.id);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.success
                      ? 'Approved ${memberWithUser.userName}'
                      : result.errorMessage ?? 'Failed to approve',
                ),
              ),
            ],
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _rejectMembership(MembershipWithUser memberWithUser) async {
    // Check permission before executing action
    // Requirements: 7.1, 7.3
    if (!_canManageMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.block, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('You don\'t have permission to manage members'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final result = await _orgRepo.rejectMembership(memberWithUser.membership.id);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.success
                      ? 'Rejected ${memberWithUser.userName}'
                      : result.errorMessage ?? 'Failed to reject',
                ),
              ),
            ],
          ),
          backgroundColor: result.success ? Colors.orange : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _removeMember(MembershipWithUser memberWithUser) async {
    // Check permission before showing confirmation
    // Requirements: 7.1, 7.3
    if (!_canManageMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.block, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('You don\'t have permission to manage members'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove ${memberWithUser.userName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _orgRepo.removeMember(memberWithUser.membership.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.success
                        ? 'Removed ${memberWithUser.userName}'
                        : result.errorMessage ?? 'Failed to remove member',
                  ),
                ),
              ],
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _transferPresidency(MembershipWithUser memberWithUser) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Transfer Presidency'),
        content: Text(
          'Are you sure you want to transfer presidency to ${memberWithUser.userName}?\n\n'
          'You will become a regular member.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _orgRepo.transferPresidency(
        orgId: widget.organizationId,
        newPresidentUserId: memberWithUser.user.id,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.success
                        ? 'Transferred presidency to ${memberWithUser.userName}'
                        : result.errorMessage ?? 'Failed to transfer presidency',
                  ),
                ),
              ],
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        if (result.success) {
          _checkUserRole();
        }
      }
    }
  }

  Future<void> _leaveOrganization() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Leave Organization'),
        content: Text(
          'Are you sure you want to leave ${widget.organizationName}?\n\n'
          'You will need to request to join again if you change your mind.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _orgRepo.leaveOrganization(widget.organizationId);
      
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Left ${widget.organizationName}'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.errorMessage ?? 'Failed to leave organization',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }
}

// Separate stateful widget for Members tab
class _MembersTabView extends StatefulWidget {
  final String orgId;
  final bool isPresident;
  final Function(MembershipWithUser) onTransferPresidency;
  final Function(MembershipWithUser) onRemoveMember;

  const _MembersTabView({
    required this.orgId,
    required this.isPresident,
    required this.onTransferPresidency,
    required this.onRemoveMember,
  });

  @override
  State<_MembersTabView> createState() => _MembersTabViewState();
}

class _MembersTabViewState extends State<_MembersTabView>
    with AutomaticKeepAliveClientMixin {
  final _orgRepo = getIt<OrgRepository>();
  final _userSession = getIt<UserSession>();

  @override
  bool get wantKeepAlive => true;

  void _showAssignTitleDialog(MembershipWithUser member) {
    showDialog(
      context: context,
      builder: (context) => OfficerTitleAssignmentDialog(
        orgId: widget.orgId,
        member: member,
      ),
    );
  }

  void _showEditPermissionsDialog(MembershipWithUser member) {
    showDialog(
      context: context,
      builder: (context) => MemberPermissionDialog(
        orgId: widget.orgId,
        member: member,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<List<MembershipWithUser>>(
      stream: _orgRepo.watchOrganizationMembers(widget.orgId),
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2196F3)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading members',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        final members = snapshot.data ?? [];

        if (members.isEmpty) {
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
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Members Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Members will appear here once they join',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final memberWithUser = members[index];
            final isCurrentUser = memberWithUser.user.id == _userSession.userId;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: memberWithUser.isPresident
                                ? Colors.amber[50]
                                : memberWithUser.hasOfficerTitle
                                    ? Colors.purple[50]
                                    : Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            memberWithUser.isPresident
                                ? Icons.star_rounded
                                : memberWithUser.hasOfficerTitle
                                    ? Icons.workspace_premium_rounded
                                    : Icons.person_rounded,
                            color: memberWithUser.isPresident
                                ? Colors.amber[700]
                                : memberWithUser.hasOfficerTitle
                                    ? Colors.purple[700]
                                    : Colors.blue[700],
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      memberWithUser.userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (memberWithUser.isPresident)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'PRESIDENT',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Show officer title if present
                              if (memberWithUser.hasOfficerTitle)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.badge_rounded,
                                        size: 14,
                                        color: Colors.purple[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        memberWithUser.officerTitleName!,
                                        style: TextStyle(
                                          color: Colors.purple[600],
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                memberWithUser.userEmail,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        if (widget.isPresident &&
                            !isCurrentUser &&
                            !memberWithUser.isPresident)
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (value) {
                              if (value == 'remove') {
                                widget.onRemoveMember(memberWithUser);
                              } else if (value == 'transfer') {
                                widget.onTransferPresidency(memberWithUser);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'transfer',
                                child: Row(
                                  children: [
                                    Icon(Icons.swap_horiz_rounded, size: 20),
                                    SizedBox(width: 12),
                                    Text('Transfer Presidency'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_remove_rounded,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Remove Member',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // Action buttons for president
                    if (widget.isPresident &&
                        !isCurrentUser &&
                        !memberWithUser.isPresident)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showAssignTitleDialog(memberWithUser),
                                icon: const Icon(Icons.badge_rounded, size: 18),
                                label: Text(
                                  memberWithUser.hasOfficerTitle
                                      ? 'Change Title'
                                      : 'Assign Title',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF9C27B0),
                                  side: const BorderSide(color: Color(0xFF9C27B0)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showEditPermissionsDialog(memberWithUser),
                                icon: const Icon(Icons.security_rounded, size: 18),
                                label: const Text(
                                  'Permissions',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2196F3),
                                  side: const BorderSide(color: Color(0xFF2196F3)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// President Members View - combines members and pending requests
class _PresidentMembersView extends StatefulWidget {
  final String orgId;
  final Function(MembershipWithUser) onTransferPresidency;
  final Function(MembershipWithUser) onRemoveMember;
  final Function(MembershipWithUser) onApproveMembership;
  final Function(MembershipWithUser) onRejectMembership;

  const _PresidentMembersView({
    required this.orgId,
    required this.onTransferPresidency,
    required this.onRemoveMember,
    required this.onApproveMembership,
    required this.onRejectMembership,
  });

  @override
  State<_PresidentMembersView> createState() => _PresidentMembersViewState();
}

class _PresidentMembersViewState extends State<_PresidentMembersView>
    with SingleTickerProviderStateMixin {
  late TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _subTabController,
            labelColor: const Color(0xFF2196F3),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF2196F3),
            indicatorWeight: 2,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'MEMBERS'),
              Tab(text: 'PENDING REQUESTS'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _MembersTabView(
                orgId: widget.orgId,
                isPresident: true,
                onTransferPresidency: widget.onTransferPresidency,
                onRemoveMember: widget.onRemoveMember,
              ),
              _PendingRequestsTabView(
                orgId: widget.orgId,
                onApproveMembership: widget.onApproveMembership,
                onRejectMembership: widget.onRejectMembership,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Separate stateful widget for Pending Requests tab
class _PendingRequestsTabView extends StatefulWidget {
  final String orgId;
  final Function(MembershipWithUser) onApproveMembership;
  final Function(MembershipWithUser) onRejectMembership;

  const _PendingRequestsTabView({
    required this.orgId,
    required this.onApproveMembership,
    required this.onRejectMembership,
  });

  @override
  State<_PendingRequestsTabView> createState() => _PendingRequestsTabViewState();
}

class _PendingRequestsTabViewState extends State<_PendingRequestsTabView>
    with AutomaticKeepAliveClientMixin {
  final _orgRepo = getIt<OrgRepository>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<List<MembershipWithUser>>(
      stream: _orgRepo.watchPendingMembers(widget.orgId),
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2196F3)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading requests',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        final pendingMembers = snapshot.data ?? [];

        if (pendingMembers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.orange[300],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Pending Requests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join requests will appear here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingMembers.length,
          itemBuilder: (context, index) {
            final memberWithUser = pendingMembers[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_add_rounded,
                            color: Colors.orange[700],
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                memberWithUser.userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                memberWithUser.userEmail,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => widget.onRejectMembership(memberWithUser),
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => widget.onApproveMembership(memberWithUser),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


// Officer Title Assignment Dialog
class OfficerTitleAssignmentDialog extends StatefulWidget {
  final String orgId;
  final MembershipWithUser member;

  const OfficerTitleAssignmentDialog({
    super.key,
    required this.orgId,
    required this.member,
  });

  @override
  State<OfficerTitleAssignmentDialog> createState() =>
      _OfficerTitleAssignmentDialogState();
}

class _OfficerTitleAssignmentDialogState
    extends State<OfficerTitleAssignmentDialog> {
  final _officerTitleRepo = getIt<OfficerTitleRepository>();
  final _newTitleController = TextEditingController();
  String? _selectedTitleId;
  bool _isCreatingNew = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _newTitleController.dispose();
    super.dispose();
  }

  Future<void> _assignTitle() async {
    if (_selectedTitleId == null) return;

    setState(() => _isLoading = true);

    final result = await _officerTitleRepo.assignOfficerTitle(
      widget.member.membership.id,
      _selectedTitleId!,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Officer title assigned to ${widget.member.userName}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(result.errorMessage ?? 'Failed to assign title'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _createAndAssignTitle() async {
    if (_newTitleController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    // Create the new title
    final createResult = await _officerTitleRepo.createOfficerTitle(
      widget.orgId,
      _newTitleController.text.trim(),
    );

    if (!createResult.success) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    createResult.errorMessage ?? 'Failed to create title',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    // Assign the newly created title
    final assignResult = await _officerTitleRepo.assignOfficerTitle(
      widget.member.membership.id,
      createResult.data!,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (assignResult.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Officer title "${_newTitleController.text.trim()}" created and assigned',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    assignResult.errorMessage ?? 'Failed to assign title',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeTitle() async {
    setState(() => _isLoading = true);

    final result = await _officerTitleRepo.removeOfficerTitle(
      widget.member.membership.id,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Officer title removed from ${widget.member.userName}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(result.errorMessage ?? 'Failed to remove title'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.badge_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Officer Title',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.member.userName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Show current title if exists
                    if (widget.member.hasOfficerTitle)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.purple[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Title',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.member.officerTitleName!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.purple[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.member.hasOfficerTitle)
                      const SizedBox(height: 16),
                    // Toggle between existing and new
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Existing Title'),
                                icon: Icon(Icons.list_rounded, size: 18),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Create New'),
                                icon: Icon(Icons.add_rounded, size: 18),
                              ),
                            ],
                            selected: {_isCreatingNew},
                            onSelectionChanged: (Set<bool> newSelection) {
                              setState(() {
                                _isCreatingNew = newSelection.first;
                                _selectedTitleId = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Existing titles list
                    if (!_isCreatingNew)
                      StreamBuilder<List<OfficerTitleModel>>(
                        stream: _officerTitleRepo.watchOfficerTitles(widget.orgId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final titles = snapshot.data ?? [];

                          if (titles.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No officer titles yet',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Create a new title to get started',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: titles.map((title) {
                              final isSelected = _selectedTitleId == title.id;
                              final isCurrent = widget.member.hasOfficerTitle &&
                                  widget.member.officerTitle?.id == title.id;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF9C27B0).withOpacity(0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF9C27B0)
                                        : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: RadioListTile<String>(
                                  value: title.id,
                                  groupValue: _selectedTitleId,
                                  onChanged: (value) {
                                    setState(() => _selectedTitleId = value);
                                  },
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title.title,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'CURRENT',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple[700],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${title.memberCount} member${title.memberCount != 1 ? 's' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  activeColor: const Color(0xFF9C27B0),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    // Create new title form
                    if (_isCreatingNew)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _newTitleController,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'Officer Title',
                              hintText: 'e.g., Vice President, Secretary',
                              prefixIcon: const Icon(Icons.badge_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 20,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This title will be created and assigned to ${widget.member.userName}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Remove title button (if member has a title)
                  if (widget.member.hasOfficerTitle && !_isCreatingNew)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _removeTitle,
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        label: const Text('Remove Title'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (widget.member.hasOfficerTitle && !_isCreatingNew)
                    const SizedBox(width: 12),
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Assign/Create button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : _isCreatingNew
                              ? (_newTitleController.text.trim().isEmpty
                                  ? null
                                  : _createAndAssignTitle)
                              : (_selectedTitleId == null ? null : _assignTitle),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isCreatingNew ? 'Create & Assign' : 'Assign Title',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Member Permission Dialog
class MemberPermissionDialog extends StatefulWidget {
  final String orgId;
  final MembershipWithUser member;

  const MemberPermissionDialog({
    super.key,
    required this.orgId,
    required this.member,
  });

  @override
  State<MemberPermissionDialog> createState() => _MemberPermissionDialogState();
}

class _MemberPermissionDialogState extends State<MemberPermissionDialog> {
  final _permissionRepo = getIt<PermissionRepository>();
  final Map<String, bool> _permissionChanges = {};
  bool _isLoading = false;
  List<PermissionModel>? _currentPermissions;
  List<PermissionModel>? _defaultPermissions;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final memberPerms = await _permissionRepo.getMemberPermissions(
      widget.member.membership.id,
    );
    final defaultPerms = await _permissionRepo.getOfficerPermissions(
      widget.orgId,
    );

    if (mounted) {
      setState(() {
        _currentPermissions = memberPerms;
        _defaultPermissions = defaultPerms;
      });
    }
  }

  bool _hasOverride(String permissionKey) {
    return _permissionChanges.containsKey(permissionKey);
  }

  bool _getPermissionValue(String permissionKey) {
    if (_permissionChanges.containsKey(permissionKey)) {
      return _permissionChanges[permissionKey]!;
    }
    return _currentPermissions
            ?.firstWhere((p) => p.key == permissionKey)
            .isGranted ??
        false;
  }

  bool _getDefaultValue(String permissionKey) {
    return _defaultPermissions
            ?.firstWhere((p) => p.key == permissionKey)
            .isGranted ??
        false;
  }

  void _togglePermission(String permissionKey, bool value) {
    setState(() {
      _permissionChanges[permissionKey] = value;
    });
  }

  void _resetToDefault(String permissionKey) {
    setState(() {
      _permissionChanges.remove(permissionKey);
    });
  }

  void _resetAllToDefault() {
    setState(() {
      _permissionChanges.clear();
    });
  }

  Future<void> _savePermissions() async {
    if (_permissionChanges.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _permissionRepo.updateMemberPermissions(
      widget.member.membership.id,
      _permissionChanges,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Permissions updated for ${widget.member.userName}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.errorMessage ?? 'Failed to update permissions',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Member Permissions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.member.userName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            if (_currentPermissions == null || _defaultPermissions == null)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Individual Overrides',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'These permissions override the default officer permissions for this member only.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Reset all button
                      if (_permissionChanges.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: OutlinedButton.icon(
                            onPressed: _resetAllToDefault,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Reset All to Default'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2196F3),
                              side: const BorderSide(
                                color: Color(0xFF2196F3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      // Permission list
                      ...Permission.all.map((permission) {
                        final currentValue = _getPermissionValue(permission.key);
                        final defaultValue = _getDefaultValue(permission.key);
                        final hasOverride = _hasOverride(permission.key);
                        final isDifferentFromDefault = currentValue != defaultValue;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: hasOverride
                                ? Colors.orange[50]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasOverride
                                  ? Colors.orange[300]!
                                  : Colors.grey[300]!,
                              width: hasOverride ? 2 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  permission.label,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              if (hasOverride)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange[100],
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'OVERRIDE',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.orange[700],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            permission.description,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          if (isDifferentFromDefault)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8),
                                              child: Text(
                                                'Default: ${defaultValue ? "Enabled" : "Disabled"}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[500],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Switch(
                                      value: currentValue,
                                      onChanged: (value) {
                                        _togglePermission(
                                            permission.key, value);
                                      },
                                      activeColor: const Color(0xFF4CAF50),
                                    ),
                                  ],
                                ),
                                if (hasOverride)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _resetToDefault(permission.key),
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Reset to Default',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.orange[700],
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _savePermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
