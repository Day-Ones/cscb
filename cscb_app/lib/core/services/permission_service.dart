import 'package:cscb_app/data/local/db/app_database.dart';
import 'package:cscb_app/core/session/user_session.dart';
import 'package:cscb_app/data/local/repositories/permission_repository.dart';
import 'package:cscb_app/core/models/permission.dart';

/// Service for checking user permissions with caching
/// Requirements: 7.1
class PermissionService {
  final AppDatabase _db;
  final UserSession _userSession;
  late final PermissionRepository _permissionRepository;

  // Cache for permission checks: "userId:orgId:permissionKey" -> bool
  final Map<String, bool> _permissionCache = {};

  PermissionService(this._db, this._userSession) {
    _permissionRepository = PermissionRepository(_db, _userSession);
  }

  /// Clear the permission cache
  /// Call this when permissions are updated
  void clearCache() {
    _permissionCache.clear();
  }

  /// Clear cache for a specific organization
  void clearCacheForOrg(String orgId) {
    _permissionCache.removeWhere((key, _) => key.contains(':$orgId:'));
  }

  /// Clear cache for a specific user
  void clearCacheForUser(String userId) {
    _permissionCache.removeWhere((key, _) => key.startsWith('$userId:'));
  }

  /// Check if the current user has a specific permission in an organization
  /// Uses caching for performance
  /// Requirements: 7.1, 7.2
  Future<bool> hasPermission(String orgId, Permission permission) async {
    if (!_userSession.isLoggedIn) {
      return false;
    }

    final userId = _userSession.userId!;
    final cacheKey = '$userId:$orgId:${permission.key}';

    // Check cache first
    if (_permissionCache.containsKey(cacheKey)) {
      return _permissionCache[cacheKey]!;
    }

    // Use PermissionRepository to check permission
    final hasPermission = await _permissionRepository.hasPermission(
      orgId,
      permission.key,
    );

    // Cache the result
    _permissionCache[cacheKey] = hasPermission;

    return hasPermission;
  }

  /// Check if the current user can create events in an organization
  /// Requirements: 3.1
  Future<bool> canCreateEvents(String orgId) async {
    return hasPermission(orgId, Permission.createEvents);
  }

  /// Check if the current user can manage members in an organization
  /// Requirements: 10.1
  Future<bool> canManageMembers(String orgId) async {
    return hasPermission(orgId, Permission.manageMembers);
  }
}
