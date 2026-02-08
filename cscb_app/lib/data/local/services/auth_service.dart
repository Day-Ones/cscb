import 'package:bcrypt/bcrypt.dart';
import '../db/app_database.dart';
import '../repositories/user_repository.dart';

/// Result of an authentication attempt
class AuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;

  AuthResult.success(this.user)
      : success = true,
        errorMessage = null;

  AuthResult.failure(this.errorMessage)
      : success = false,
        user = null;
}

/// Service for handling user authentication
class AuthService {
  final UserRepository _userRepository;

  AuthService(this._userRepository);

  /// Verify a password against a hash
  bool _verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (e) {
      return false;
    }
  }

  /// Authenticate user with email and password
  Future<AuthResult> authenticate(String email, String password) async {
    try {
      // Get user by email
      final user = await _userRepository.getUserByEmail(email);

      // User not found
      if (user == null) {
        return AuthResult.failure('Invalid email or password');
      }

      // Verify password
      final isPasswordValid = _verifyPassword(password, user.passwordHash);

      if (!isPasswordValid) {
        return AuthResult.failure('Invalid email or password');
      }

      // Authentication successful
      return AuthResult.success(user);
    } catch (e) {
      // Graceful error handling - don't expose internal details
      return AuthResult.failure('Authentication failed. Please try again.');
    }
  }
}
