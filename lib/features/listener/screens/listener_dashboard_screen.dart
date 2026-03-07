import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../home/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'listener_incoming_call_screen.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../wallet/services/wallet_service.dart';
import '../../profile/screens/profile_screen.dart';
import 'session_history_screen.dart';
import 'rating_history_screen.dart';
import '../../auth/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../call/services/request_service.dart';
import '../../call/models/help_request.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'listener_active_call_screen.dart';

class ListenerDashboardScreen extends StatefulWidget {
  const ListenerDashboardScreen({super.key});

  @override
  State<ListenerDashboardScreen> createState() =>
      _ListenerDashboardScreenState();
}

// ...

class _ListenerDashboardScreenState extends State<ListenerDashboardScreen> {
  bool _isOnline = false;
  String _handle = "User";
  final _userService = UserService();
  final _auth = FirebaseAuth.instance;
  final _requestService = RequestService();
  List<HelpRequest> _openRequests = [];
  int _sessionCount = 0;
  double _rating = 0.0;

  final Set<String> _selectedTopics = {"Lonely", "Relationships"};

  final List<String> _availableTopics = [
    "Anxious",
    "Lonely",
    "Can't Sleep",

    "Relationships",
    "Depression",
  ];

  @override
  void initState() {
    super.initState();
    _loadHandle();

    // 1. Check Immediately
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _loadStatus(currentUser.uid);
      _loadStats(currentUser.uid);
    }

    // 2. Listen for Auth Changes (covers initial load if slow, or re-login)
    _auth.authStateChanges().listen((user) {
      if (user != null && mounted) {
        _loadStatus(user.uid);
        _loadStats(user.uid);
      }
    });

    // 3. Stream open requests if online
    _listenToOpenRequests();
  }

  StreamSubscription? _requestsSub;

  void _listenToOpenRequests() {
    _requestsSub?.cancel();
    _requestsSub = _requestService
        .streamOpenRequests(_selectedTopics.toList())
        .listen((requests) {
          if (mounted) {
            setState(() {
              _openRequests = requests;
            });
          }
        });
  }

  Future<void> _loadStats(String uid) async {
    final stats = await _requestService.getListenerStats(uid);
    if (mounted) {
      setState(() {
        _sessionCount = stats['sessions'];
        _rating = stats['rating'];
      });
    }
  }

  Future<void> _loadStatus(String uid) async {
    try {
      final userDoc = await _userService.getUser(uid);
      if (mounted && userDoc != null) {
        setState(() {
          _isOnline = userDoc.isOnline;
          if (userDoc.topics.isNotEmpty) {
            _selectedTopics.clear();
            _selectedTopics.addAll(userDoc.topics);
          }
        });
      }
    } catch (e) {
      // Error fetching status
    }
  }

  Future<void> _loadHandle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _handle = prefs.getString('handle') ?? "User";
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _toggleStatus(bool value) {
    setState(() {
      _isOnline = value;
    });

    // Update status in Firestore
    final user = _auth.currentUser;
    if (user != null) {
      _userService.updateListenerStatus(user.uid, value).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to update status: $e"),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isOnline = !value); // Revert
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: No User Logged In"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isOnline = !value); // Revert
    }

    // Real requests will appear via Firestore stream
  }

  void _switchBackToSeeker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isListener', false);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen(isListener: false)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Hi, $_handle",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white),
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
                      listenable: WalletService(),
                      builder: (context, _) {
                        return Text(
                          "₹${WalletService().balance.toInt()}",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // REJOIN CALL BANNER
            StreamBuilder<List<HelpRequest>>(
              stream: _requestService.streamActiveRequests(
                _auth.currentUser?.uid ?? "",
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final activeRequest = snapshot.data!.first;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.8),
                          Colors.teal.withOpacity(0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.call, color: Colors.white),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Call in Progress",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "You have an unfinished session.",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (activeRequest.status == 'pending' ||
                                activeRequest.status == 'accepted') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ListenerIncomingCallScreen(
                                    requestId: activeRequest.id,
                                    seekerName: activeRequest.seekerHandle,
                                    topic: activeRequest.topic,
                                  ),
                                ),
                              );
                            } else if (activeRequest.status == 'connected') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ListenerActiveCallScreen(
                                    requestId: activeRequest.id,
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.green,
                          ),
                          child: const Text("Rejoin"),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            // Status Toggle Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: MidnightTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Text(
                    _isOnline ? "ONLINE" : "OFFLINE",
                    style: TextStyle(
                      color: _isOnline
                          ? MidnightTheme.primaryColor
                          : Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Transform.scale(
                    scale: 1.5,
                    child: Switch(
                      value: _isOnline,
                      onChanged: _toggleStatus,
                      activeThumbColor: MidnightTheme.primaryColor,
                      activeTrackColor: MidnightTheme.primaryColor.withOpacity(
                        0.3,
                      ),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isOnline
                        ? "Scanning for requests..."
                        : "Slide to start your shift",
                    style: TextStyle(
                      color: _isOnline
                          ? MidnightTheme.primaryColor
                          : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    "Sessions",
                    "$_sessionCount",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SessionHistoryScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    "Karma",
                    "$_rating ★",
                    isStar: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RatingHistoryScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Row

            // Topic Filters
            const Text(
              "I am open to discussing:",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableTopics.map((topic) {
                return _buildFilterChip(topic, _selectedTopics.contains(topic));
              }).toList(),
            ),

            if (_isOnline && _openRequests.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text(
                "Open Requests",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Real Requests from Firestore
              ..._openRequests.map(
                (request) => _buildRequestTile(
                  request.seekerHandle,
                  request.topic,
                  "Active User",
                  onTap: () async {
                    // Claim the request (sets to 'pending')
                    final user = _auth.currentUser;
                    if (user != null) {
                      try {
                        await _requestService.claimRequest(
                          request.id,
                          user.uid,
                          _handle,
                        );
                        if (mounted) {
                          // Prevent receiving new requests while busy
                          _toggleStatus(false);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListenerIncomingCallScreen(
                                requestId: request.id,
                                seekerName: request.seekerHandle,
                                topic: request.topic,
                                userTier: "Active User",
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to claim: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ),
            ] else if (_isOnline && _openRequests.isEmpty) ...[
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.withOpacity(0.3),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No requests right now",
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.bedtime,
                      color: Colors.white.withOpacity(0.2),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Go Online to see requests",
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value, {
    bool isStar = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: MidnightTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool value) async {
        setState(() {
          if (value) {
            _selectedTopics.add(label);
          } else {
            _selectedTopics.remove(label);
          }
        });

        // Re-subscribe with new topics if currently online
        if (_isOnline) {
          _listenToOpenRequests();
        }

        // Save preferences to Firestore immediately
        final user = _auth.currentUser;
        if (user != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
                  'topics': _selectedTopics.toList(),
                }, SetOptions(merge: true));
          } catch (e) {
            // Failed to save topic preference
          }
        }
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
          color: isSelected
              ? MidnightTheme.primaryColor
              : Colors.white.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _buildRequestTile(
    String name,
    String topic,
    String tag, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MidnightTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.1),
                child: const Icon(Icons.person, color: Colors.white70),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic,
                      style: const TextStyle(
                        color: MidnightTheme.primaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
