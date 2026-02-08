import 'package:flutter/material.dart';
import '../core/di/locator.dart';
import '../data/local/services/auth_service_with_remote.dart';
import '../data/local/repositories/user_repository.dart';
import '../data/remote/repositories/remote_user_repository.dart';
import '../data/remote/services/google_auth_service.dart';
import '../data/local/db/app_database.dart';
import 'package:drift/drift.dart' hide Column;
import 'main_page.dart';
import 'admin_approval_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isFormValid = false;
  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;
  
  late final AuthServiceWithRemote _authService;
  final _googleAuthService = GoogleAuthService();

  @override
  void initState() {
    super.initState();
    _authService = getIt<AuthServiceWithRemote>();
    _usernameController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  void _validateForm() {
    setState(() {
      _isFormValid =
          _usernameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty;
      // Clear error message when user modifies input
      if (_errorMessage != null) {
        _errorMessage = null;
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.authenticate(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.success) {
      _currentUser = result.user;
      _navigateBasedOnRole(result.user!.role);
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
      });
    }
  }

  void _navigateBasedOnRole(String role) {
    if (role == 'super_admin') {
      // Navigate to admin approval page for super admin
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminApprovalPage()),
      );
    } else {
      // Navigate to main page for president/member
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainPage(user: _currentUser!)),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _googleAuthService.signInWithGoogle();

    if (!mounted) return;

    if (result.success) {
      // Create/update user in database
      try {
        final userRepo = getIt<UserRepository>();
        final remoteUserRepo = getIt<RemoteUserRepository>();
        
        // Check if user already exists
        final existingUser = await userRepo.getUserByEmail(result.email!);
        
        if (existingUser == null) {
          // Create new user locally
          final newUser = UsersCompanion(
            id: Value(result.userId!),
            email: Value(result.email!),
            name: Value(result.name ?? result.email!),
            role: const Value('member'), // Google users are members by default
            passwordHash: const Value(''), // No password for Google users
            isSynced: const Value(false),
            deleted: const Value(false),
          );
          
          await userRepo.createUser(newUser);
          
          // Sync to Supabase
          await remoteUserRepo.createUser({
            'id': result.userId!,
            'email': result.email!,
            'name': result.name ?? result.email!,
            'role': 'member',
            'password_hash': '',
            'is_synced': true,
            'deleted': false,
          });
          
          // Fetch the created user
          _currentUser = await userRepo.getUserByEmail(result.email!);
        } else {
          _currentUser = existingUser;
        }
        
        setState(() {
          _isLoading = false;
        });
        
        // Navigate to main page (Google users are regular users, not admins)
        if (_currentUser != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainPage(user: _currentUser!)),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to create user: $e';
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.lightBlue,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username or Email',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: Colors.lightBlue,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.lightBlue),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.lightBlue),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.lightBlue,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.lightBlue),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_isFormValid && !_isLoading) ? _signIn : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isFormValid && !_isLoading)
                      ? Colors.lightBlue
                      : Colors.grey[300],
                  foregroundColor: (_isFormValid && !_isLoading)
                      ? Colors.white
                      : Colors.grey[500],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: (_isFormValid && !_isLoading) ? 2 : 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[400])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[400])),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: Image.network(
                  'https://www.google.com/favicon.ico',
                  height: 24,
                  width: 24,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
                ),
                label: const Text(
                  'Sign in with Google',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
