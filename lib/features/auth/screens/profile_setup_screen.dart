import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final handle = _handleController.text.trim();

    try {
      final newUser = UserModel(
        uid: widget.uid,
        email: widget.phoneNumber, // We use phoneNumber as email fallback for now
        handle: handle,
        role: _isListener ? 'listener' : 'seeker',
        isOnline: _isListener,
        topics: [],
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
