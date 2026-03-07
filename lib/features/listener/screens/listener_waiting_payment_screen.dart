import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../call/services/request_service.dart';
import '../../call/models/help_request.dart';
import 'dart:async';
import 'listener_earnings_screen.dart';

class ListenerWaitingPaymentScreen extends StatefulWidget {
  final String requestId;
  final Duration callDuration;

  const ListenerWaitingPaymentScreen({
    super.key,
    required this.requestId,
    required this.callDuration,
  });

  @override
  State<ListenerWaitingPaymentScreen> createState() =>
      _ListenerWaitingPaymentScreenState();
}

class _ListenerWaitingPaymentScreenState
    extends State<ListenerWaitingPaymentScreen>
    with SingleTickerProviderStateMixin {
  final RequestService _requestService = RequestService();
  StreamSubscription<HelpRequest?>? _requestSubscription;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _listenForPayment();
  }

  void _listenForPayment() {
    // Listen for when Seeker completes payment (status becomes 'completed')
    _requestSubscription = _requestService
        .streamRequestById(widget.requestId)
        .listen((request) {
          if (request != null && request.status == 'completed' && mounted) {
            // Payment received! Navigate to earnings screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ListenerEarningsScreen(
                  requestId: widget.requestId,
                  callDuration: widget.callDuration,
                ),
              ),
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
    final minutes = widget.callDuration.inMinutes;
    final seconds = widget.callDuration.inSeconds % 60;
    final basePay = AppConstants.sessionBasePay;

    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Loading Spinner
              RotationTransition(
                turns: _controller,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MidnightTheme.primaryColor,
                      width: 4,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        MidnightTheme.primaryColor,
                        MidnightTheme.primaryColor.withOpacity(0.1),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Waiting Message
              const Text(
                "Waiting for payment...",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "The seeker is reviewing the call",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 48),

              // Call Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: MidnightTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Call Duration
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Call Duration",
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          "${minutes}m ${seconds}s",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),

                    // Estimated Earnings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Guaranteed Earnings",
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          "₹$basePay",
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "+ any tip from the seeker",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
