import 'package:flutter/material.dart';
import 'package:cscb_app/core/di/locator.dart';
import 'package:cscb_app/core/models/permission_model.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';

/// Permission settings page for managing default officer permissions
/// Requirements: 5.2, 11.2, 11.3
class PermissionSettingsPage extends StatefulWidget {
  final String organizationId;
  final String organizationName;

  const PermissionSettingsPage({
    super.key,
    required this.organizationId,
    required this.organizationName,
  });

  @override
  State<PermissionSettingsPage> createState() => _PermissionSettingsPageState();
}

class _PermissionSettingsPageState extends State<PermissionSettingsPage> {
  final _permissionRepo = getIt<PermissionRepository>();

  List<PermissionModel> _permissions = [];
  final Map<String, bool> _pendingChanges = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  /// Load current officer permissions for the organization
  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);

    try {
      final permissions = await _permissionRepo.getOfficerPermissions(
        widget.organizationId,
      );

      setState(() {
        _permissions = permissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load permissions: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Handle permission toggle
  /// Requirements: 5.3, 5.4, 11.4, 11.5
  void _onPermissionToggled(String permissionKey, bool newValue) {
    setState(() {
      // Update local state
      _pendingChanges[permissionKey] = newValue;

      // Update the permission in the list for immediate UI feedback
      final index = _permissions.indexWhere((p) => p.key == permissionKey);
      if (index != -1) {
        _permissions[index] = _permissions[index].copyWith(isGranted: newValue);
      }
    });
  }

  /// Save permission changes to database
  /// Requirements: 5.3, 5.4, 11.4, 11.5
  Future<void> _savePermissions() async {
    if (_pendingChanges.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Save to database and sync to Supabase
      final result = await _permissionRepo.updateOfficerPermissions(
        widget.organizationId,
        _pendingChanges,
      );

      if (result.success) {
        if (mounted) {
          // Show confirmation message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissions updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Navigate back
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Failed to update permissions'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving permissions: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Officer Permissions',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.organizationName,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_pendingChanges.isNotEmpty)
            TextButton(
              onPressed: _isSaving ? null : _savePermissions,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2196F3),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2196F3)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.blue[700],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Default permissions for officers in this organization',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Permission list
                  ..._permissions.map((permission) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPermissionCard(permission),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  /// Build a single permission card with toggle switch
  /// Requirements: 5.2, 11.2, 11.3
  Widget _buildPermissionCard(PermissionModel permission) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: permission.isGranted
                  ? const Color(0xFF2196F3).withOpacity(0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getPermissionIcon(permission.key),
              color: permission.isGranted
                  ? const Color(0xFF2196F3)
                  : Colors.grey[400],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Label and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permission.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  permission.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Toggle switch
          Switch(
            value: permission.isGranted,
            onChanged: (value) => _onPermissionToggled(permission.key, value),
            activeTrackColor: const Color(0xFF2196F3),
          ),
        ],
      ),
    );
  }

  /// Get icon for permission type
  IconData _getPermissionIcon(String permissionKey) {
    switch (permissionKey) {
      case 'create_events':
        return Icons.add_circle_outline_rounded;
      case 'edit_events':
        return Icons.edit_outlined;
      case 'delete_events':
        return Icons.delete_outline_rounded;
      case 'manage_members':
        return Icons.people_outline_rounded;
      case 'assign_officers':
        return Icons.badge_outlined;
      case 'edit_organization':
        return Icons.business_outlined;
      case 'view_analytics':
        return Icons.analytics_outlined;
      case 'manage_permissions':
        return Icons.security_outlined;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }
}
