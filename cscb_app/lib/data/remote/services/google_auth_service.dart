import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  // Web OAuth Client ID from Google Cloud Console
  static const String _webClientId = '803724261051-63iobii3pn7qs6gnuqc55cvbu0vua3p6.apps.googleusercontent.com';
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _webClientId, // Required for ID token
  );

  /// Sign in with Google using native Google Sign-In
  Future<GoogleAuthResult> signInWithGoogle() async {
    try {
      // Sign out first to force account selection
      await _googleSignIn.signOut();
      
      // Show native Google Sign-In picker
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return GoogleAuthResult.failure('Google sign-in was cancelled');
      }

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Return success with Google user info
      // The app will create a local user record with this info
      return GoogleAuthResult.success(
        userId: googleUser.id,
        email: googleUser.email,
        name: googleUser.displayName ?? googleUser.email,
        photoUrl: googleUser.photoUrl,
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
    } catch (e) {
      return GoogleAuthResult.failure('Google sign-in failed: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Get current user
  GoogleSignInAccount? getCurrentUser() {
    return _googleSignIn.currentUser;
  }

  /// Check if user is signed in
  bool isSignedIn() {
    return _googleSignIn.currentUser != null;
  }
}

class GoogleAuthResult {
  final bool success;
  final String? userId;
  final String? email;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? photoUrl;
  final String? idToken;
  final String? accessToken;
  final String? errorMessage;

  GoogleAuthResult.success({
    required this.userId,
    required this.email,
    required this.name,
    this.photoUrl,
    this.idToken,
    this.accessToken,
  })  : success = true,
        firstName = _parseFirstName(name),
        lastName = _parseLastName(name),
        errorMessage = null;

  GoogleAuthResult.failure(this.errorMessage)
      : success = false,
        userId = null,
        email = null,
        name = null,
        firstName = null,
        lastName = null,
        photoUrl = null,
        idToken = null,
        accessToken = null;

  /// Parse first name from full name (everything before first space)
  static String? _parseFirstName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return null;
    final parts = fullName.trim().split(' ');
    return parts.first;
  }

  /// Parse last name from full name (everything after first space)
  static String? _parseLastName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return null;
    final parts = fullName.trim().split(' ');
    if (parts.length <= 1) return null;
    return parts.sublist(1).join(' ');
  }
}
