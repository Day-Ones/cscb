/// Singleton class to manage the currently logged-in user session
class UserSession {
  static final UserSession _instance = UserSession._internal();
  
  factory UserSession() => _instance;
  
  UserSession._internal();

  String? _userId;
  String? _email;
  String? _name;
  String? _role;

  /// Set the current user session
  void setCurrentUser({
    required String userId,
    required String email,
    required String name,
    required String role,
  }) {
    _userId = userId;
    _email = email;
    _name = name;
    _role = role;
  }

  /// Get the current user ID
  String? get userId => _userId;

  /// Get the current user email
  String? get email => _email;

  /// Get the current user name
  String? get name => _name;

  /// Get the current user role
  String? get role => _role;

  /// Check if a user is currently logged in
  bool get isLoggedIn => _userId != null;

  /// Check if current user is super admin
  bool get isSuperAdmin => _role == 'super_admin';

  /// Clear the current user session (logout)
  void clearCurrentUser() {
    _userId = null;
    _email = null;
    _name = null;
    _role = null;
  }

  /// Get current user data as a map
  Map<String, String>? getCurrentUser() {
    if (!isLoggedIn) return null;
    
    return {
      'userId': _userId!,
      'email': _email!,
      'name': _name!,
      'role': _role!,
    };
  }
}
