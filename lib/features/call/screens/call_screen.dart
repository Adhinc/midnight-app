import 'package:flutter/material.dart';
import 'dart:async';

import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../call/services/request_service.dart';
import '../../call/models/help_request.dart';
import '../../wallet/services/wallet_service.dart';
import '../../profile/services/moderation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../call/services/agora_service.dart';

class CallScreen extends StatefulWidget {
  final String requestId;

  const CallScreen({super.key, required this.requestId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  final RequestService _requestService = RequestService();
  final ModerationService _moderationService = ModerationService(); // New
  StreamSubscription<HelpRequest?>? _requestSubscription;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final int _currentRating = 0;
  bool _isAgoraConnected = false;
  final _agoraService = AgoraService();
  bool _isMuted = false;
  Timer? _timer;
  Duration _duration = Duration.zero;
  bool _isEndingCall = false;
  bool _paymentProcessed = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenForCallEnd();
    _initAgora();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  String _debugLog = "";

  Future<void> _initAgora() async {
    _agoraService.onLog = (msg) {
      if (mounted) setState(() => _debugLog = msg); // Show last log
    };

    await _agoraService.initialize();

    _agoraService.onJoinChannelSuccess = (conn, elapsed) {
      if (mounted) {
        setState(() {
          _isAgoraConnected = true;
          _debugLog = "Joined Channel!";
        });
      }
    };

    _agoraService.onError = (err, msg) {
      if (mounted) setState(() => _debugLog = "ERROR: $err - $msg");
    };

    _agoraService.onUserJoined = (uid, elapsed) {
      // Listener joined or other peer
    };

    // Use a random int ID for now, or hash the user ID
    final uid = DateTime.now().millisecondsSinceEpoch % 1000000;
    await _agoraService.joinChannel(channelId: widget.requestId, uid: uid);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _requestService.streamRequestById(widget.requestId).listen((_) {}).cancel();
    _requestSubscription?.cancel();
    _agoraService.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration += const Duration(seconds: 1);
        });
      }
    });
  }

  void _listenForCallEnd() {
    // Listen for when Listener ends call (status becomes 'ending')
    _requestSubscription = _requestService
        .streamRequestById(widget.requestId)
        .listen((request) {
          if (request != null && request.status == 'ending' && mounted) {
            // Listener ended call! Show rating dialog
            if (!_isEndingCall) {
              _showTippingDialog(context);
            }
          }
        });
  }

  void _showEndCallConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "End Call?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Are you sure you want to end this call?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showTippingDialog(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text("End Call"),
          ),
        ],
      ),
    );
  }

  void _showTippingDialog(BuildContext context) async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    // First, end the call if not already ended
    try {
      final request = await _requestService.getRequestById(widget.requestId);
      if (request?.status == 'connected') {
        await _requestService.endCall(widget.requestId);
      }
    } catch (e) {
      // Call might already be ended
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        int localRating = 0;
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              backgroundColor: MidnightTheme.bgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListenableBuilder(
                      listenable: WalletService(),
                      builder: (context, _) => Text(
                        "Account Balance: ₹${WalletService().balance.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "How was your session?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rating Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          onPressed: () {
                            setDialogState(() {
                              localRating = index + 1;
                            });
                          },
                          icon: Icon(
                            index < localRating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      "Support your listener.",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Flexible(
                          child: _TipOption(
                            amount: 20,
                            onTap: () {
                              Navigator.of(
                                dialogContext,
                              ).pop({'rating': localRating, 'tip': 20});
                            },
                          ),
                        ),
                        Flexible(
                          child: _TipOption(
                            amount: 50,
                            isPrimary: true,
                            onTap: () {
                              Navigator.of(
                                dialogContext,
                              ).pop({'rating': localRating, 'tip': 50});
                            },
                          ),
                        ),
                        Flexible(
                          child: _TipOption(
                            amount: 100,
                            onTap: () {
                              Navigator.of(
                                dialogContext,
                              ).pop({'rating': localRating, 'tip': 100});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                        ).pop({'rating': localRating, 'tip': 0});
                      },
                      child: const Text(
                        "Skip for now",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted && !_paymentProcessed) {
      _paymentProcessed = true;
      final tip = result['tip'] ?? 0;
      final totalAmount = AppConstants.sessionCost + tip; // Base pay + tip

      // Deduct from Seeker's Wallet (awaited — ensures Firestore write completes)
      try {
        final success = await WalletService().makePayment(
          totalAmount.toDouble(),
          "Session Payment",
        );
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("₹$totalAmount deducted from your wallet.")),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Insufficient balance. Payment skipped."),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Payment failed: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      // Complete the call with rating and tip
      await _requestService.completeCall(
        widget.requestId,
        result['rating'] ?? 0,
        tip,
      );
      // Return to previous screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showModerationOptions(BuildContext context, HelpRequest request) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MidnightTheme.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Options",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.orange),
                title: const Text(
                  "Report User",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(context, request);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text(
                  "Block User & End Session",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlockAction(context, request);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showReportDialog(BuildContext context, HelpRequest request) {
    final reportReasons = [
      'Inappropriate behavior',
      'Harassment',
      'Spam/Advertising',
      'Other',
    ];
    String selectedReason = reportReasons.first;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: MidnightTheme.surfaceColor,
              title: const Text(
                "Report User",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Why are you reporting this user?",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ...reportReasons.map((reason) {
                    return RadioListTile<String>(
                      title: Text(
                        reason,
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: reason,
                      fillColor: WidgetStateProperty.resolveWith(
                        (states) => MidnightTheme.primaryColor,
                      ),
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setDialogState(() => selectedReason = value!);
                      },
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext); // Close dialog immediately

                    // Determine the ID of the *other* person in the call
                    final myUid = FirebaseAuth.instance.currentUser?.uid;
                    final otherUserId = (request.seekerId == myUid)
                        ? request.listenerId
                        : request.seekerId;

                    if (otherUserId != null) {
                      try {
                        await _moderationService.reportUser(
                          reportedUid: otherUserId,
                          reason: selectedReason,
                          requestId: widget.requestId,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Report submitted successfully."),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Failed to submit report."),
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text(
                    "Submit Report",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmBlockAction(BuildContext context, HelpRequest request) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: MidnightTheme.surfaceColor,
        title: const Text("Block User?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will immediately end the session and prevent them from matching with you ever again.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog

              // Determine the ID of the *other* person in the call
              final myUid = FirebaseAuth.instance.currentUser?.uid;
              final otherUserId = (request.seekerId == myUid)
                  ? request.listenerId
                  : request.seekerId;

              if (otherUserId != null) {
                // Block them
                await _moderationService.blockUser(blockedUid: otherUserId);

                // End call (they will be kicked out when the stream updates)
                if (!_isEndingCall) {
                  try {
                    await _requestService.endCall(widget.requestId);
                  } catch (e) {
                    // Error ending call during block
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("User blocked and session ended."),
                      ),
                    );

                    // Explicitly trigger the tipping/rating dialog flow
                    _showTippingDialog(context);
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Block", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Options Button in top Right
            Positioned(
              top: 16,
              right: 16,
              child: FutureBuilder<HelpRequest?>(
                future: _requestService.getRequestById(widget.requestId),
                builder: (context, snapshot) {
                  return IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      if (snapshot.hasData && snapshot.data != null) {
                        _showModerationOptions(context, snapshot.data!);
                      }
                    },
                  );
                },
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Avatar
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E1E2C),
                            boxShadow: [
                              BoxShadow(
                                color: MidnightTheme.secondaryColor.withOpacity(
                                  0.4 * _pulseAnimation.value,
                                ),
                                blurRadius: 40 * _pulseAnimation.value,
                                spreadRadius: 10 * _pulseAnimation.value,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Status Text
                  Text(
                    _isAgoraConnected
                        ? "Voice Connected"
                        : "Connecting to Audio...",
                    style: TextStyle(
                      color: _isAgoraConnected
                          ? Colors.greenAccent.shade400
                          : Colors.white70,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Timer
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Bottom Controls
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 50),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black, Colors.black.withOpacity(0.0)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // End Call
                    GestureDetector(
                      onTap: () => _showEndCallConfirmation(context),
                      child: _buildOptionBtn(
                        Icons.call_end,
                        "End Call",
                        Colors.white,
                        bgColor: Colors.redAccent.shade400,
                      ),
                    ),
                    const SizedBox(width: 48),
                    // Mute Button
                    GestureDetector(
                      onTap: _toggleMute,
                      child: _buildOptionBtn(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        _isMuted ? "Unmuted" : "Mute",
                        _isMuted ? Colors.redAccent : Colors.white,
                        bgColor: _isMuted
                            ? Colors.red.withOpacity(0.15)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionBtn(
    IconData icon,
    String label,
    Color color, {
    Color? bgColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: bgColor ?? Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: bgColor == Colors.redAccent.shade400
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _agoraService.muteLocalAudio(_isMuted);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

class _RatingBar extends StatefulWidget {
  final ValueChanged<int> onRatingChanged;

  const _RatingBar({required this.onRatingChanged});

  @override
  State<_RatingBar> createState() => _RatingBarState();
}

class _RatingBarState extends State<_RatingBar> {
  int _currentRating = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return IconButton(
          onPressed: () {
            setState(() {
              _currentRating = index + 1;
            });
            widget.onRatingChanged(_currentRating);
          },
          icon: Icon(
            index < _currentRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 32,
          ),
        );
      }),
    );
  }
}

class _TipOption extends StatelessWidget {
  final int amount;
  final VoidCallback onTap;
  final bool isPrimary;

  const _TipOption({
    required this.amount,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 16,
          horizontal: isPrimary ? 32 : 24,
        ),
        decoration: BoxDecoration(
          color: isPrimary
              ? MidnightTheme.secondaryColor
              : MidnightTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          "₹$amount",
          style: TextStyle(
            color: isPrimary ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isPrimary ? 20 : 16,
          ),
        ),
      ),
    );
  }
}
