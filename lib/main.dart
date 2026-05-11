import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme.dart';
import 'features/auth/screens/phone_login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'core/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: .env file missing. Using system env or defaults.");
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final isListener = prefs.getBool('isListener') ?? false;

  // Validate that Firebase Auth session is still active
  final currentUser = FirebaseAuth.instance.currentUser;
  final hasValidAuth = isLoggedIn && currentUser != null;
  
  if (isLoggedIn && !hasValidAuth) {
    // Session expired or user deleted — clear local markers but KEEP handle/role if user exists in DB
    // Actually, it's safer to clear everything and let them re-login if the auth token is dead
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
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    // Initialize push notifications when a user logs in
    _authSub = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        NotificationService().initialize();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

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
