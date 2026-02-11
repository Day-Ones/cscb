import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../core/di/locator.dart';
import '../data/local/repositories/user_profile_repository.dart';
import '../data/remote/services/google_auth_service.dart';
import '../data/local/db/app_database.dart';
import 'package:drift/drift.dart' hide Column;
import 'main_page.dart';

class ProfileSetupPage extends StatefulWidget {
  final User user;
  final GoogleAuthResult googleResult;

  const ProfileSetupPage({
    super.key,
    required this.user,
    required this.googleResult,
  });

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _studentNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  String? _selectedProgram;
  int? _selectedYearLevel;
  String? _selectedSection;

  bool _showYearLevel = false;
  bool _isFormValid = false;
  bool _isSaving = false;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize with Google data
    _firstNameController.text = widget.googleResult.firstName ?? '';
    _lastNameController.text = widget.googleResult.lastName ?? '';

    // Setup animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Add listeners
    _studentNumberController.addListener(_validateForm);
    _firstNameController.addListener(_validateForm);
    _lastNameController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _studentNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onProgramChanged(String? program) {
    setState(() {
      _selectedProgram = program;
      _selectedYearLevel = null; // Reset year level when program changes
      
      if (program != null) {
        _showYearLevel = true;
        _animationController.forward();
      } else {
        _showYearLevel = false;
        _animationController.reverse();
      }
    });
    _validateForm();
  }

  List<int> _getYearLevelOptions() {
    if (_selectedProgram == 'DIT') {
      return [1, 2, 3];
    }
    return [1, 2, 3, 4];
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _studentNumberController.text.isNotEmpty &&
          _firstNameController.text.isNotEmpty &&
          _lastNameController.text.isNotEmpty &&
          _selectedProgram != null &&
          _selectedYearLevel != null &&
          _selectedSection != null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_isFormValid || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final profileRepo = getIt<UserProfileRepository>();
      final uuid = const Uuid();

      final profile = UserProfilesCompanion(
        id: Value(uuid.v4()),
        userId: Value(widget.user.id),
        googleId: Value(widget.googleResult.userId),
        studentNumber: Value(_studentNumberController.text.trim()),
        firstName: Value(_firstNameController.text.trim()),
        lastName: Value(_lastNameController.text.trim()),
        fullName: Value('${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'),
        program: Value(_selectedProgram!),
        yearLevel: Value(_selectedYearLevel!),
        section: Value(_selectedSection!),
        isComplete: const Value(true),
        isSynced: const Value(false),
        deleted: const Value(false),
      );

      await profileRepo.createUserProfile(profile);

      if (!mounted) return;

      // Navigate to organization discovery/main page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainPage(user: widget.user)),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: 0.5, // Step 1 of 2
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlue),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      
                      // Header
                      Text(
                        'Set up your Profile',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Step 1 of 2',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Student Number Field
                      TextFormField(
                        controller: _studentNumberController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Student Number',
                          hintText: 'Enter your student number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.lightBlue, width: 2),
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your student number';
                          }
                          if (value.length < 6) {
                            return 'Student number must be at least 6 digits';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // First Name Field
                      TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          hintText: 'Enter your first name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.lightBlue, width: 2),
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Last Name Field
                      TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          hintText: 'Enter your last name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.lightBlue, width: 2),
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Program Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedProgram,
                        decoration: InputDecoration(
                          labelText: 'Program',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.lightBlue, width: 2),
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                        items: ['BSIT', 'DIT', 'BSEdEn', 'BSEdMath'].map((program) {
                          return DropdownMenuItem(
                            value: program,
                            child: Text(program),
                          );
                        }).toList(),
                        onChanged: _onProgramChanged,
                        validator: (value) {
                          if (value == null) {
                            return 'Please select your program';
                          }
                          return null;
                        },
                      ),
                      
                      // Year Level Dropdown (Conditional)
                      if (_showYearLevel) ...[
                        const SizedBox(height: 16),
                        SlideTransition(
                          position: _slideAnimation,
                          child: DropdownButtonFormField<int>(
                            value: _selectedYearLevel,
                            decoration: InputDecoration(
                              labelText: 'Year Level',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.lightBlue, width: 2),
                              ),
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                            ),
                            items: _getYearLevelOptions().map((year) {
                              return DropdownMenuItem(
                                value: year,
                                child: Text('Year $year'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedYearLevel = value;
                              });
                              _validateForm();
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select your year level';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      // Section Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedSection,
                        decoration: InputDecoration(
                          labelText: 'Section',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.lightBlue, width: 2),
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                        items: ['1', '2', '1L', '2L'].map((section) {
                          return DropdownMenuItem(
                            value: section,
                            child: Text('Section $section'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSection = value;
                          });
                          _validateForm();
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select your section';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 80), // Space for sticky button
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      
      // Sticky Complete Setup Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_isFormValid && !_isSaving) ? _saveProfile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFormValid ? Colors.lightBlue : Colors.grey[300],
                foregroundColor: _isFormValid ? Colors.white : Colors.grey[500],
                elevation: _isFormValid ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Complete Setup',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
