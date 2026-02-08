import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:cscb_app/core/di/locator.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/data/local/repositories/org_repository.dart';
import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/data/remote/repositories/remote_org_repository.dart';
import 'login_page.dart';

class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({super.key});

  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  final _orgRepo = getIt<OrgRepository>();
  final _remoteOrgRepo = getIt<RemoteOrgRepository>();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganizationsFromSupabase();
  }

  Future<void> _loadOrganizationsFromSupabase() async {
    try {
      // Fetch all organizations from Supabase
      final remoteOrgs = await _remoteOrgRepo.getAllOrganizations();
      
      // Sync them to local database
      for (var orgData in remoteOrgs) {
        await _orgRepo.db.into(_orgRepo.db.organizations).insertOnConflictUpdate(
          OrganizationsCompanion.insert(
            id: orgData['id'],
            name: orgData['name'],
            status: Value(orgData['status']),
            isSynced: const Value(true),
            deleted: Value(orgData['deleted'] ?? false),
          ),
        );
      }
    } catch (e) {
      // If Supabase fetch fails, just use local data
      debugPrint('Failed to load organizations from Supabase: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveOrganization(Organization org) async {
    final result = await _orgRepo.approveOrganization(org.id);
    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved: ${org.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to approve'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteOrganization(Organization org) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Organization'),
        content: Text('Are you sure you want to delete "${org.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _orgRepo.deleteOrganization(org.id);
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted: ${org.name}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Failed to delete'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _suspendOrganization(Organization org) async {
    final result = await _orgRepo.suspendOrganization(org.id);
    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Suspended: ${org.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Failed to suspend'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Management'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Clear user session on logout
              final userSession = getIt<UserSession>();
              userSession.clearCurrentUser();
              
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Organization>>(
              stream: _orgRepo.watchAllOrganizations(),
              builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final orgs = snapshot.data ?? [];

          if (orgs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No organizations pending approval',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orgs.length,
            itemBuilder: (context, index) {
              final org = orgs[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => _showOrganizationDetails(org),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.lightBlue[100],
                              child: const Icon(Icons.business, color: Colors.lightBlue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    org.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(org.status),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      org.status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (org.status == 'pending') ...[
                              OutlinedButton.icon(
                                onPressed: () => _approveOrganization(org),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Approve'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (org.status == 'active') ...[
                              OutlinedButton.icon(
                                onPressed: () => _suspendOrganization(org),
                                icon: const Icon(Icons.pause_circle_outline),
                                label: const Text('Suspend'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            OutlinedButton.icon(
                              onPressed: () => _deleteOrganization(org),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showOrganizationDetails(Organization org) async {
    // Get the president (creator) of the organization
    final membership = await (_orgRepo.db.select(_orgRepo.db.memberships)
          ..where((tbl) =>
              tbl.orgId.equals(org.id) & tbl.role.equals('president')))
        .getSingleOrNull();

    String creatorInfo = 'Unknown';
    if (membership != null) {
      final user = await (_orgRepo.db.select(_orgRepo.db.users)
            ..where((tbl) => tbl.id.equals(membership.userId)))
          .getSingleOrNull();
      if (user != null) {
        creatorInfo = '${user.name} (${user.email})';
      }
    }

    // Get member count
    final memberCount = await (_orgRepo.db.select(_orgRepo.db.memberships)
          ..where((tbl) =>
              tbl.orgId.equals(org.id) & tbl.status.equals('approved')))
        .get()
        .then((list) => list.length);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(org.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Status', org.status.toUpperCase()),
              const SizedBox(height: 12),
              _buildDetailRow('President', creatorInfo),
              const SizedBox(height: 12),
              _buildDetailRow('Members', memberCount.toString()),
              const SizedBox(height: 12),
              _buildDetailRow('Organization ID', org.id),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
