import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../call/screens/match_radar_screen.dart';
import '../../listener/screens/listener_dashboard_screen.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../call/services/request_service.dart';
import '../../call/models/help_request.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../wallet/services/wallet_service.dart';
import '../../call/services/connection_service.dart';
class HomeScreen extends StatefulWidget {
  final bool isListener;
  const HomeScreen({super.key, required this.isListener});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _handle = "User";
  final _auth = FirebaseAuth.instance;
  final _walletService = WalletService();
  
  // List of pages for navigation
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadHandle();
    _pages = [
      const _ExplorePage(),
      const _ConnectedPage(),
    ];
  }

  Future<void> _loadHandle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _handle = prefs.getString('handle') ?? "User";
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isListener) {
      return const ListenerDashboardScreen();
    }

    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _currentIndex == 0 ? "Hi, $_handle" : "Stay Connected",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.person, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: MidnightTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MidnightTheme.primaryColor.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: MidnightTheme.secondaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    ListenableBuilder(
                      listenable: _walletService,
                      builder: (context, _) {
                        return Text(
                          "₹${_walletService.balance.toInt()}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: MidnightTheme.surfaceColor,
        selectedItemColor: MidnightTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: "Explore",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: "Connected",
          ),
        ],
      ),
    );
  }
}

class _ExplorePage extends StatefulWidget {
  const _ExplorePage();

  @override
  State<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<_ExplorePage> {
  String? selectedMood;
  final _requestService = RequestService();
  final _auth = FirebaseAuth.instance;
  final _walletService = WalletService();
  bool _isProcessing = false;
  String _handle = "User";

  @override
  void initState() {
    super.initState();
    _loadHandle();
  }

  Future<void> _loadHandle() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _handle = prefs.getString('handle') ?? "User";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              "How are you feeling?",
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 24),

            // Mood Chips
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                _MoodChip(
                  label: "Anxious",
                  emoji: "😰",
                  color: Colors.purple,
                  isSelected: selectedMood == "Anxious",
                  onTap: () => setState(() => selectedMood = "Anxious"),
                ),
                _MoodChip(
                  label: "Lonely",
                  emoji: "😔",
                  color: Colors.blue,
                  isSelected: selectedMood == "Lonely",
                  onTap: () => setState(() => selectedMood = "Lonely"),
                ),
                _MoodChip(
                  label: "Can't Sleep",
                  emoji: "😴",
                  color: Colors.orange,
                  isSelected: selectedMood == "Can't Sleep",
                  onTap: () => setState(() => selectedMood = "Can't Sleep"),
                ),

                _MoodChip(
                  label: "Relationships",
                  emoji: "❤️",
                  color: Colors.pink,
                  isSelected: selectedMood == "Relationships",
                  onTap: () => setState(() => selectedMood = "Relationships"),
                ),
                _MoodChip(
                  label: "Depression",
                  emoji: "🌧️",
                  color: Colors.indigo,
                  isSelected: selectedMood == "Depression",
                  onTap: () => setState(() => selectedMood = "Depression"),
                ),
              ],
            ),

            const Spacer(),

            // Low-balance warning banner
            ListenableBuilder(
              listenable: _walletService,
              builder: (context, _) {
                final balance = _walletService.balance;
                final sessionCost = AppConstants.sessionCost.toDouble();
                if (balance >= sessionCost) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Insufficient balance. Sessions cost ₹$sessionCost. Tap to add money.",
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.amber,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Hero Button
            Center(
              child: ListenableBuilder(
                listenable: _walletService,
                builder: (context, _) {
                  final hasBalance =
                      _walletService.balance >= AppConstants.sessionCost;
                  return GestureDetector(
                    onTap: () async {
                      if (_isProcessing) return;

                      if (selectedMood == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Please select a mood to find a listener.",
                            ),
                          ),
                        );
                        return;
                      }

                      // ── Wallet balance check ──
                      if (!hasBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "You need at least ₹${AppConstants.sessionCost} to start a session.",
                            ),
                            action: SnackBarAction(
                              label: 'Add Money',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WalletScreen(),
                                ),
                              ),
                            ),
                          ),
                        );
                        return;
                      }

                      // Create real request in Firestore
                      setState(() => _isProcessing = true);
                      try {
                        final user = _auth.currentUser;
                        if (user == null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please log in first"),
                              ),
                            );
                          }
                          return;
                        }

                        // Re-check balance from Firestore before creating request
                        final userDoc = await FirebaseFirestore.instance
                            .collection('users').doc(user.uid).get();
                        final liveBalance = (userDoc.data()?['walletBalance'] ?? 0.0).toDouble();
                          return;
                        }

                        // ── Wallet Hold ──
                        final holdSuccess = await _walletService.holdFunds(AppConstants.sessionCost.toDouble());
                        if (!holdSuccess) {
                           if (mounted) {
                            setState(() => _isProcessing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Insufficient available balance. You might already have a pending request."),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }

                        final request = HelpRequest(
                          id: '', // Will be set by Firestore
                          seekerId: user.uid,
                          seekerHandle: _handle,
                          topic: selectedMood!,
                          mood: selectedMood!,
                          status: 'open',
                          timestamp: DateTime.now(),
                          language: List<String>.from(userDoc.data()?['languages'] ?? ['English'])[0],
                        );

                        final requestId = await _requestService.createRequest(
                          request,
                        );

                        // Navigate to radar screen with request ID
                        if (mounted) {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  MatchRadarScreen(requestId: requestId),
                            ),
                          );
                        }
                      } catch (e) {
                        // Release hold on failure
                        await _walletService.releaseHeldFunds(AppConstants.sessionCost.toDouble());
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error creating request: $e"),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isProcessing = false);
                        }
                      }
                    },
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: hasBalance
                              ? [
                                  MidnightTheme.primaryColor.withOpacity(0.8),
                                  MidnightTheme.primaryColor.withOpacity(0.2),
                                ]
                              : [
                                  Colors.grey.withOpacity(0.4),
                                  Colors.grey.withOpacity(0.1),
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: hasBalance
                                ? MidnightTheme.primaryColor.withOpacity(0.4)
                                : Colors.grey.withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          hasBalance ? "Find\nListener" : "Add\nFunds",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: hasBalance ? Colors.white : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
  void _startTargetedCall(Map<String, dynamic> listener) async {
    if (_isProcessing) return;
    
    // Validate balance
    if (_walletService.balance < AppConstants.sessionCost) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient balance to call this listener.")),
      );
      return;
    }

    if (!listener['isOnline']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${listener['handle']} is currently offline.")),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final request = HelpRequest(
        id: '',
        seekerId: user.uid,
        seekerHandle: _handle,
        topic: (listener['topics'] as List).isNotEmpty ? listener['topics'][0] : "General",
        mood: "Reconnecting",
        status: 'open',
        timestamp: DateTime.now(),
        listenerId: listener['id'], // Target this specific listener
        language: listener['language'] ?? 'English',
      );

      final requestId = await _requestService.createRequest(request);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MatchRadarScreen(requestId: requestId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _ConnectedPage extends StatefulWidget {
  const _ConnectedPage();

  @override
  State<_ConnectedPage> createState() => _ConnectedPageState();
}

class _ConnectedPageState extends State<_ConnectedPage> {
  final _walletService = WalletService();
  final _requestService = RequestService();
  final _auth = FirebaseAuth.instance;
  bool _isProcessing = false;
  String _handle = "User";

  @override
  void initState() {
    super.initState();
    _loadHandle();
  }

  Future<void> _loadHandle() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _handle = prefs.getString('handle') ?? "User";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Listeners",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "People you've connected with before.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ConnectionService().streamStayConnectedListeners(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: MidnightTheme.primaryColor));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 64, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text(
                          "No listeners saved yet.",
                          style: TextStyle(color: Colors.white.withOpacity(0.3)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Add listeners after a call or from your history.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                final listeners = snapshot.data!;
                return ListView.builder(
                  itemCount: listeners.length,
                  itemBuilder: (context, index) {
                    final listener = listeners[index];
                    return _FavoriteListenerTile(
                      handle: listener['handle'],
                      isOnline: listener['isOnline'],
                      onTap: () => _startTargetedCall(listener),
                      onRemove: () => ConnectionService().removeFromStayConnected(listener['id']),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _startTargetedCall(Map<String, dynamic> listener) async {
    if (_isProcessing) return;
    
    if (_walletService.balance < AppConstants.sessionCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient balance.")),
      );
      return;
    }

    if (!listener['isOnline']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${listener['handle']} is offline.")),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final request = HelpRequest(
        id: '',
        seekerId: user.uid,
        seekerHandle: _handle,
        topic: (listener['topics'] as List).isNotEmpty ? listener['topics'][0] : "General",
        mood: "Reconnecting",
        status: 'open',
        timestamp: DateTime.now(),
        listenerId: listener['id'],
        language: listener['language'] ?? 'English',
      );

      final requestId = await _requestService.createRequest(request);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MatchRadarScreen(requestId: requestId)),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _FavoriteListenerTile extends StatelessWidget {
  final String handle;
  final bool isOnline;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteListenerTile({
    required this.handle,
    required this.isOnline,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MidnightTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.1),
              child: const Icon(Icons.person, color: Colors.white),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: MidnightTheme.surfaceColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          handle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isOnline ? "Available to talk" : "Offline",
          style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOnline)
              const Icon(Icons.phone_in_talk, color: MidnightTheme.primaryColor),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodChip({
    required this.label,
    required this.emoji,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : MidnightTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
