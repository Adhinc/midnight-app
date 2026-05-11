import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme.dart';
import 'features/auth/screens/phone_login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final isListener = prefs.getBool('isListener') ?? false;

  // Validate that Firebase Auth session is still active
  final hasValidAuth = isLoggedIn && FirebaseAuth.instance.currentUser != null;
  if (isLoggedIn && !hasValidAuth) {
    // Session expired or user deleted — clear stale local data
    await prefs.clear();
  }

  runApp(
    MidnightApp(isLoggedIn: hasValidAuth, isListener: isListener),
  );
}

class MidnightApp extends StatefulWidget {
  final bool isLoggedIn;
  final bool isListener;
  
  const MidnightApp({super.key, required this.isLoggedIn, required this.isListener});

  @override
  State<MidnightApp> createState() => _MidnightAppState();
}

class _MidnightAppState extends State<MidnightApp> {
  // We need to fetch prefs again if we removed main() await logic or just pass them through
  // For safety, let's keep the main() logic but remove DevicePreview

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Midnight',
      debugShowCheckedModeBanner: false,
      theme: MidnightTheme.darkTheme,
      home: widget.isLoggedIn ? HomeScreen(isListener: widget.isListener) : const PhoneLoginScreen(),
    );
  }
}
