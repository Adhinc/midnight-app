import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/theme.dart';
import 'listener_waiting_payment_screen.dart';
import '../../call/services/request_service.dart';
import '../../call/models/help_request.dart';
import '../../call/services/agora_service.dart';

class ListenerActiveCallScreen extends StatefulWidget {
  final String requestId;

  const ListenerActiveCallScreen({super.key, required this.requestId});

  @override
  State<ListenerActiveCallScreen> createState() =>
      _ListenerActiveCallScreenState();
}

class _ListenerActiveCallScreenState extends State<ListenerActiveCallScreen>
    with SingleTickerProviderStateMixin {
  final RequestService _requestService = RequestService();
  StreamSubscription<HelpRequest?>? _requestSubscription;
  Timer? _timer;
  Duration _duration = Duration.zero;
  bool _isMuted = false;

  final List<String> _prompts = [
    "What's on your mind right now?",
    "How long have you been feeling this way?",
    "What do you think triggered these feelings?",
    "What usually helps you when you feel like this?",
    "I'm here to listen, take your time.",
  ];
  int _currentPromptIndex = 0;
  bool _isAgoraConnected = false;
  final _agoraService = AgoraService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenForCallEnd();
    _setupAgora(); // Renamed from _initAgora

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  String _debugLog = "";

  Future<void> _setupAgora() async {
    // Renamed from _initAgora
    // 1. Setup Logger FIRST
    _agoraService.onLog = (msg) {
      if (mounted) setState(() => _debugLog = msg);
    };

    try {
      // 2. Initialize Agora IMMEDIATELY
      await _agoraService.initialize();

      // 3. Setup Events
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
        // Seeker joined
      };

      _agoraService.onUserOffline = (uid) {
        // Seeker left the call
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("The other person has left the call."),
              backgroundColor: Colors.orange,
            ),
          );
          // End the call from listener side
          _requestService.endCall(widget.requestId);
        }
      };

      // 4. Join Channel
      // Use a random int ID for now, or hash the user ID
      final uid = DateTime.now().millisecondsSinceEpoch % 1000000;
      await _agoraService.joinChannel(channelId: widget.requestId, uid: uid);

      // 5. Sync timer (LAST, so it doesn't block audio)
      final request = await _requestService.getRequestById(widget.requestId);
      if (request?.connectedAt != null && mounted) {
        setState(() {
          final diff = DateTime.now().difference(request!.connectedAt!);
          _duration = diff.isNegative ? Duration.zero : diff;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _debugLog = "INIT EXCEPTION: $e");
    }
  }

  void _listenForCallEnd() {
    // Listen for when call ends (status becomes 'ending')
    _requestSubscription = _requestService
        .streamRequestById(widget.requestId)
        .listen((request) {
          if (request != null &&
              (request.status == 'ending' ||
                  request.status == 'completed' ||
                  request.status == 'cancelled') &&
              mounted) {
            // Call ended! Navigate to waiting screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ListenerWaitingPaymentScreen(
                  requestId: widget.requestId,
                  callDuration: _duration,
                ),
              ),
            );
          }
        });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _requestSubscription?.cancel();
    // Clear Agora callbacks to prevent firing after dispose
    _agoraService.onLog = null;
    _agoraService.onJoinChannelSuccess = null;
    _agoraService.onError = null;
    _agoraService.onUserJoined = null;
    _agoraService.onUserOffline = null;
    _agoraService.leaveChannel();
    _agoraService.dispose();
    _pulseController.dispose();
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _agoraService.muteLocalAudio(_isMuted);
  }

  void _cyclePrompt() {
    setState(() {
      _currentPromptIndex = (_currentPromptIndex + 1) % _prompts.length;
    });
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MidnightTheme.surfaceColor,
        title: const Text("Report User", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to report this user? This will end the call immediately.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text(
              "Report & End",
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              // End call and navigate to waiting screen
              await _requestService.endCall(widget.requestId);
              // The stream listener will handle navigation
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showEndCallConfirmation(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
        child: Stack(
          children: [
            // Center Avatar & Info
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
                    "Voice Active",
                    style: TextStyle(
                      color: Colors.greenAccent.shade400,
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

                  // Prompt Overlay
                  GestureDetector(
                    onTap: _cyclePrompt,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 16,
                                color: Colors.amber.shade300,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Try asking:",
                                style: TextStyle(
                                  color: Colors.amber.shade300,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.refresh,
                                size: 14,
                                color: Colors.amber.shade300,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "\"${_prompts[_currentPromptIndex]}\"",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Top Bar
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text(
                          "Encrypted",
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Report / Safety Eject
                  IconButton(
                    onPressed: _showReportDialog,
                    icon: const Icon(Icons.security, color: Colors.red),
                    tooltip: "Report User",
                  ),
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
                    const SizedBox(width: 48),
                    // End Call
                    GestureDetector(
                      onTap: () => _showEndCallConfirmation(context),
                      child: _buildOptionBtn(
                        Icons.call_end,
                        "End",
                        Colors.white,
                        bgColor: Colors.redAccent.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
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
            onPressed: () async {
              Navigator.pop(ctx);
              await _requestService.endCall(widget.requestId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text("End Call"),
          ),
        ],
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
}
