import 'package:bcrypt/bcrypt.dart';
import '../db/app_database.dart';
import '../repositories/user_repository.dart';
import '../../remote/repositories/remote_user_repository.dart';
import 'package:drift/drift.dart';

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

/// Service for handling user authentication with Supabase integration
class AuthServiceWithRemote {
  final UserRepository _localUserRepository;
  final RemoteUserRepository _remoteUserRepository;

  AuthServiceWithRemote(
    this._localUserRepository,
    this._remoteUserRepository,
  );

  /// Verify a password against a hash
  bool _verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (e) {
      return false;
    }
  }

  /// Authenticate user with email and password
  /// Tries Supabase first, then falls back to local database
  Future<AuthResult> authenticate(String email, String password) async {
    try {
      // Try to fetch user from Supabase first
      User? user;
      try {
        final remoteUser = await _remoteUserRepository.getUserByEmail(email);
        if (remoteUser != null) {
          // Sync to local database
          await _localUserRepository.createUser(UsersCompanion(
            id: Value(remoteUser['id']),
            name: Value(remoteUser['name']),
            email: Value(remoteUser['email']),
            passwordHash: Value(remoteUser['password_hash']),
            role: Value(remoteUser['role']),
            isSynced: const Value(true),
            deleted: Value(remoteUser['deleted'] ?? false),
          ));
          
          // Get from local after sync
          user = await _localUserRepository.getUserByEmail(email);
        }
      } catch (e) {
        // If Supabase fails, try local database
        user = await _localUserRepository.getUserByEmail(email);
      }

      // User not found in either database
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
