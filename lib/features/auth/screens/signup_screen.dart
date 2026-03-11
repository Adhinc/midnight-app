import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/validators.dart';
import '../../home/screens/home_screen.dart';
import '../services/auth_repository.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _handleController = TextEditingController();
  bool _isListener = false;

  final AuthRepository _authRepository = AuthRepository();
  final UserService _userService = UserService();
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final handle = _handleController.text.trim();

    setState(() => _isLoading = true);

    try {
      // 1. Create Auth User & Set Display Name
      final user = await _authRepository.signUpWithEmail(email, password, handle: handle);

      if (user != null) {
        // 2. Create User Document in Firestore
        final newUser = UserModel(
          uid: user.uid,
          email: email,
          handle: handle,
          role: _isListener ? 'listener' : 'seeker',
          isOnline: _isListener,
          topics: [],
          createdAt: DateTime.now(),
        );

        try {
          await _userService.createUser(newUser);
        } catch (e) {
          // Rollback: delete auth user if Firestore profile creation fails
          await user.delete();
          rethrow;
        }

        // 3. Save Profile Data Locally (Sync)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('handle', handle);
        await prefs.setBool('isListener', _isListener);

        // 4. Navigate
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen(isListener: _isListener)),
            (route) => false,
          );
        }
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
    _emailController.dispose();
    _passwordController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
      ),
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
                  Text("Join Midnight", style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: 8),
                  Text("Create your anonymous account.", style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 48),

                  // Handle
                  TextFormField(
                    controller: _handleController,
                    maxLength: 20,
                    validator: Validators.handle,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Public Handle (Display Name)",
                      labelStyle: const TextStyle(color: MidnightTheme.textSecondary),
                      filled: true,
                      fillColor: MidnightTheme.surfaceColor.withOpacity(0.8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterStyle: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: const TextStyle(color: MidnightTheme.textSecondary),
                      filled: true,
                      fillColor: MidnightTheme.surfaceColor.withOpacity(0.8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    validator: Validators.password,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Password",
                      helperText: "Min 8 chars, 1 uppercase, 1 number",
                      helperStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      labelStyle: const TextStyle(color: MidnightTheme.textSecondary),
                      filled: true,
                      fillColor: MidnightTheme.surfaceColor.withOpacity(0.8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Role Switch
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

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text("Create Account"),
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
