import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme.dart';
import '../../../core/validators.dart';
import '../../home/screens/home_screen.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String uid;
  final String phoneNumber;

  const ProfileSetupScreen({
    super.key,
    required this.uid,
    required this.phoneNumber,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _handleController = TextEditingController();
  bool _isListener = false;
  bool _isLoading = false;
  final UserService _userService = UserService();
  List<String> _selectedLanguages = ['English'];
  final List<String> _allLanguages = [
    'English',
    'Hindi',
    'Malayalam',
    'Tamil',
    'Telugu',
    'Kannada',
    'Bengali',
    'Marathi',
    'Gujarati',
  ];

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final handle = _handleController.text.trim();

    try {
      // 1. Check Handle Uniqueness
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('handle', isEqualTo: handle)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty && query.docs.first.id != widget.uid) {
        throw "Handle already taken. Please choose another one.";
      }

      final newUser = UserModel(
        uid: widget.uid,
        phone: widget.phoneNumber,
        handle: handle,
        role: _isListener ? 'listener' : 'seeker',
        isOnline: false, // Always start offline until they pick topics
        topics: [],
        languages: _selectedLanguages,
        createdAt: DateTime.now(),
      );

      await _userService.createUser(newUser);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('handle', handle);
      await prefs.setBool('isListener', _isListener);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen(isListener: _isListener)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Create Profile", style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: 8),
                  Text("Choose how you want to appear.", style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 48),

                  TextFormField(
                    controller: _handleController,
                    maxLength: 20,
                    validator: Validators.handle,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Public Handle",
                      labelStyle: const TextStyle(color: MidnightTheme.textSecondary),
                      filled: true,
                      fillColor: MidnightTheme.surfaceColor.withOpacity(0.8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: const Text("I want to be a Listener"),
                    subtitle: const Text("Earn money by listening to others."),
                    value: _isListener,
                    activeThumbColor: MidnightTheme.secondaryColor,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _isListener = val;
                      });
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "Languages you speak",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allLanguages.map((lang) {
                      final isSelected = _selectedLanguages.contains(lang);
                      return FilterChip(
                        label: Text(lang),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedLanguages.add(lang);
                            } else {
                              if (_selectedLanguages.length > 1) {
                                _selectedLanguages.remove(lang);
                              }
                            }
                          });
                        },
                        backgroundColor: MidnightTheme.surfaceColor,
                        selectedColor: MidnightTheme.primaryColor.withOpacity(0.2),
                        checkmarkColor: MidnightTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected ? MidnightTheme.primaryColor : Colors.white,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? MidnightTheme.primaryColor : Colors.white.withOpacity(0.1),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _completeSetup,
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text("Finish Setup"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
