import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import 'listener_active_call_screen.dart';
import '../../call/services/request_service.dart';
import '../../call/models/help_request.dart';
import 'dart:async';
import '../../call/services/agora_service.dart';

class ListenerIncomingCallScreen extends StatefulWidget {
  final String requestId;
  final String seekerName;
  final String topic;
  final String userTier;

  const ListenerIncomingCallScreen({
    super.key,
    required this.requestId,
    this.seekerName = "Anonymous",
    this.topic = "Feeling Anxious",
    this.userTier = "Gold Tier User",
  });

  @override
  State<ListenerIncomingCallScreen> createState() => _ListenerIncomingCallScreenState();
}

class _ListenerIncomingCallScreenState extends State<ListenerIncomingCallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final RequestService _requestService = RequestService();
  StreamSubscription<HelpRequest?>? _requestSubscription;
  bool _hasAccepted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _listenForConnection();
  }

  void _listenForConnection() {
    // Listen for when Seeker clicks "Connect" (status becomes 'connected')
    _requestSubscription = _requestService.streamRequestById(widget.requestId).listen((request) {
      if (request != null && request.status == 'connected' && mounted) {
        // Both users enter call simultaneously
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ListenerActiveCallScreen(requestId: widget.requestId)),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _requestSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Pulsing "Incoming Call" Badge
              Column(
                children: [
                  FadeTransition(
                    opacity: _controller,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.red, size: 12),
                          SizedBox(width: 8),
                          Text("INCOMING CALL...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),

              // Context Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: MidnightTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: MidnightTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: MidnightTheme.primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, size: 40, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),

                    // Topic
                    Text(
                      widget.topic,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),

                    // User Tier Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD700)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 16),
                          const SizedBox(width: 4),
                          Text(widget.userTier, style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Caller Name
                    Text(
                      "Caller: ${widget.seekerName}",
                      style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 24),

                    // Timer
                    const Text(
                      "Waiting for 15s...",
                      style: TextStyle(fontSize: 14, color: Colors.white54),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(MidnightTheme.primaryColor),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Action Buttons
              Row(
                children: [
                  // Decline Button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 24),
                  
                  // Accept Button (Massive)
                  Expanded(
                    child: ScaleTransition(
                      scale: Tween(begin: 0.95, end: 1.05).animate(_controller),
                      child: ElevatedButton(
                        onPressed: _hasAccepted ? null : () async {
                          // Request Mic Permission on User Tap
                          await AgoraService().requestPermissions();

                          // Accept the request (sets status to 'accepted')
                          try {
                            await _requestService.acceptRequest(widget.requestId);
                            setState(() {
                              _hasAccepted = true;
                            });
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Failed to accept: $e"), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676), // Bright Green
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 10,
                        ),
                        child: Column(
                          children: [
                            const Text("Accept & Earn", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text("Earn ₹30 guaranteed", style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.8))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
