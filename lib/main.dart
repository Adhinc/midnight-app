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
import 'features/listener/screens/listener_incoming_call_screen.dart';
import 'features/call/services/request_service.dart';
import 'dart:async';

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
  StreamSubscription<String>? _navSub;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize push notifications when a user logs in
    _authSub = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        NotificationService().initialize();
        _setupNotificationListener();
      }
    });
  }

  void _setupNotificationListener() {
    _navSub?.cancel();
    _navSub = NotificationService().requestNavigationStream.listen((requestId) async {
      // 1. Fetch request details to show the correct name/topic
      final request = await RequestService().getRequestById(requestId);
      if (request != null && _navigatorKey.currentState != null) {
        // 2. Navigate to incoming call screen
        _navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ListenerIncomingCallScreen(
              requestId: requestId,
              seekerName: request.seekerHandle,
              topic: request.topic,
              userTier: request.listenerId != null ? "Direct Request" : "Active User",
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _navSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Midnight',
      debugShowCheckedModeBanner: false,
      theme: MidnightTheme.darkTheme,
      home: widget.isLoggedIn ? HomeScreen(isListener: widget.isListener) : const PhoneLoginScreen(),
    );
  }
}
