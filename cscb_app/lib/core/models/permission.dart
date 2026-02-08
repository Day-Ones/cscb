/// Enum representing all available permissions in the system
enum Permission {
  createEvents('create_events', 'Create Events', 'Create and schedule events'),
  editEvents('edit_events', 'Edit Events', 'Modify existing events'),
  deleteEvents('delete_events', 'Delete Events', 'Remove events'),
  manageMembers('manage_members', 'Manage Members', 'Approve and remove members'),
  assignOfficers('assign_officers', 'Assign Officer Titles', 'Assign officer titles to members'),
  editOrganization('edit_organization', 'Edit Organization Details', 'Modify organization information'),
  viewAnalytics('view_analytics', 'View Analytics', 'Access organization statistics'),
  managePermissions('manage_permissions', 'Manage Permissions', 'Configure permission settings');

  const Permission(this.key, this.label, this.description);

  final String key;
  final String label;
  final String description;

  /// Get Permission enum from key string
  static Permission? fromKey(String key) {
    try {
      return Permission.values.firstWhere((p) => p.key == key);
    } catch (e) {
      return null;
    }
  }

  /// Get all permission keys
  static List<String> get allKeys => Permission.values.map((p) => p.key).toList();

  /// Get all permissions as a list
  static List<Permission> get all => Permission.values;
}
