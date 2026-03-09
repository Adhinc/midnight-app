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
import '../../wallet/services/wallet_service.dart';
class HomeScreen extends StatefulWidget {
  final bool isListener;
  const HomeScreen({super.key, required this.isListener});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // walletBalance removed
  String? selectedMood;
  String _handle = "User";
  final _requestService = RequestService();
  final _auth = FirebaseAuth.instance;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadHandle();
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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

            const SizedBox(height: 24),


            const Spacer(),

            // Low-balance warning banner
            ListenableBuilder(
              listenable: WalletService(),
              builder: (context, _) {
                final balance = WalletService().balance;
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
                listenable: WalletService(),
                builder: (context, _) {
                  final hasBalance =
                      WalletService().balance >= AppConstants.sessionCost;
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

                        final request = HelpRequest(
                          id: '', // Will be set by Firestore
                          seekerId: user.uid,
                          seekerHandle: _handle,
                          topic: selectedMood!,
                          mood: selectedMood!,
                          status: 'open',
                          timestamp: DateTime.now(),
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
