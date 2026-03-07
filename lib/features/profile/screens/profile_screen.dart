import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/services/auth_repository.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/account_settings_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/help_support_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../listener/screens/listener_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isListener = false;
  String _handle = "User";
  String? _profilePicUrl;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isListener = prefs.getBool('isListener') ?? false;
      _handle = prefs.getString('handle') ?? "User";
      _profilePicUrl = prefs.getString('profilePicUrl');
    });
  }

  String _getJoinDate() {
    final user = FirebaseAuth.instance.currentUser;
    final creationTime = user?.metadata.creationTime;
    if (creationTime == null) return "Member";
    return "Member since ${DateFormat('MMM yyyy').format(creationTime)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Header
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: MidnightTheme.surfaceColor,
                backgroundImage:
                    _profilePicUrl != null && _profilePicUrl!.isNotEmpty
                    ? NetworkImage(_profilePicUrl!)
                    : null,
                child: _profilePicUrl == null || _profilePicUrl!.isEmpty
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _handle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(_getJoinDate(), style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),

            // Options List
            _ProfileOption(
              icon: Icons.edit,
              title: "Edit Profile",
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                _loadUserRole();
              },
            ),
            _ProfileOption(
              icon: Icons.settings,
              title: "Account Settings",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountSettingsScreen(),
                ),
              ),
            ),
            _ProfileOption(
              icon: Icons.history,
              title: "Session History",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SessionHistoryScreen()),
              ),
            ),

            // Dynamic Mode Switcher
            _ProfileOption(
              icon: _isListener ? Icons.directions_walk : Icons.headphones,
              title: _isListener
                  ? "Switch to Seeker Mode"
                  : "Switch to Listener Mode",
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                // Toggle the state
                final newStatus = !_isListener;
                await prefs.setBool('isListener', newStatus);

                if (!mounted) return;

                if (newStatus) {
                  // Switching to Listener
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Switching to Listener Mode..."),
                    ),
                  );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ListenerDashboardScreen(),
                    ),
                    (route) => false,
                  );
                } else {
                  // Switching to Seeker
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Switching back to Seeker Mode..."),
                    ),
                  );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeScreen(isListener: false),
                    ),
                    (route) => false,
                  );
                }
              },
            ),
            _ProfileOption(
              icon: Icons.help_outline,
              title: "Help & Support",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              ),
            ),
            const SizedBox(height: 24),
            _ProfileOption(
              icon: Icons.logout,
              title: "Logout",
              isDestructive: true,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // Clear all local data
                await AuthRepository().signOut(); // Sign out of Firebase

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MidnightTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Icon(icon, color: isDestructive ? Colors.red : Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDestructive ? Colors.red : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
