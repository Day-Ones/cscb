import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/local/db/app_database.dart';
import '../data/remote/repositories/remote_user_profile_repository.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final User user;
  
  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _appVersion = '';
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  final _remoteProfileRepo = RemoteUserProfileRepository();
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    await Future.wait([
      _loadAppVersion(),
      _loadUserProfile(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }
  
  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }
  
  Future<void> _loadUserProfile() async {
    try {
      final profile = await _remoteProfileRepo.getUserProfileByUserId(widget.user.id);
      setState(() {
        _userProfile = profile;
      });
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showFAQ,
            tooltip: 'FAQ',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Profile Avatar
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.lightBlue,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  
                  // Name
                  Text(
                    _userProfile?['name'] ?? widget.user.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Email
                  Text(
                    widget.user.email,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  
                  // Info Cards
                  if (_userProfile != null) ...[
                    _buildInfoCard(
                      icon: Icons.school,
                      label: 'Program',
                      value: _userProfile!['program'] ?? 'Not set',
                    ),
                    const SizedBox(height: 12),
                    
                    _buildInfoCard(
                      icon: Icons.grade,
                      label: 'Year Level & Section',
                      value: _formatYearLevelSection(
                        _userProfile!['year_level'],
                        _userProfile!['section'],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Profile not set up. Please contact admin.',
                              style: TextStyle(color: Colors.orange[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  _buildInfoCard(
                    icon: Icons.phone_android,
                    label: 'App Version',
                    value: _appVersion.isNotEmpty ? _appVersion : 'Loading...',
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // FAQ Button
                  OutlinedButton.icon(
                    onPressed: _showFAQ,
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Frequently Asked Questions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.lightBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Colors.lightBlue),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Logout Button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.lightBlue, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatYearLevelSection(dynamic yearLevel, dynamic section) {
    if (yearLevel == null || section == null) return 'Not set';
    return '$yearLevel-$section';
  }
  
  void _showFAQ() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.lightBlue,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.help_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFAQItem(
                    question: 'How do I update my profile information?',
                    answer: 'Contact your organization administrator to update your profile information including name, program, and year level.',
                  ),
                  _buildFAQItem(
                    question: 'How do I join an organization?',
                    answer: 'Navigate to the Organization page and request to join. Your request will be reviewed by the organization president or super admin.',
                  ),
                  _buildFAQItem(
                    question: 'What are the different user roles?',
                    answer: 'There are three roles:\n• Super Admin - Full system access\n• President - Manage organization members\n• Member - Basic access to organization features',
                  ),
                  _buildFAQItem(
                    question: 'How do I check event attendance?',
                    answer: 'Event attendance is tracked automatically when you check in to events through the app. View your attendance history in the Events section.',
                  ),
                  _buildFAQItem(
                    question: 'What should I do if I forgot my password?',
                    answer: 'Contact your system administrator to reset your password. Alternatively, you can sign in using Google Sign-In.',
                  ),
                  _buildFAQItem(
                    question: 'How do I sign out?',
                    answer: 'Tap the "Logout" button at the bottom of your profile page to sign out of the app.',
                  ),
                  _buildFAQItem(
                    question: 'Can I use the app offline?',
                    answer: 'Yes! The app supports offline mode. Your data will sync automatically when you reconnect to the internet.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFAQItem({required String question, required String answer}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
