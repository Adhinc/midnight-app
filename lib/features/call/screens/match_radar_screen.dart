import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme.dart';
import 'call_screen.dart';
import '../models/listener_model.dart';
import '../services/request_service.dart';
import 'dart:async';

class MatchRadarScreen extends StatefulWidget {
  final String requestId;

  const MatchRadarScreen({super.key, required this.requestId});

  @override
  State<MatchRadarScreen> createState() => _MatchRadarScreenState();
}

class _MatchRadarScreenState extends State<MatchRadarScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _matchFound = false;
  ListenerProfile? _matchedListener;
  final _requestService = RequestService();
  StreamSubscription? _requestSubscription;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startScanning();
    _startTimeout();
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(minutes: 2), () {
      if (!_matchFound && mounted) {
        _requestService.cancelRequest(widget.requestId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No listeners available. Please try again.")),
        );
        Navigator.of(context).pop();
      }
    });
  }

  void _startScanning() {
    // Listen to request status changes
    _requestSubscription = _requestService
        .streamRequestById(widget.requestId)
        .listen(
          (request) async {
            if (request != null && request.status == 'accepted' && mounted) {

              // Fetch actual listener profile data from Firestore
              String lId = request.listenerId ?? '';
              Map<String, dynamic> userData = {};
              if (lId.isNotEmpty) {
                try {
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(lId)
                      .get();
                  userData = userDoc.data() ?? {};
                } catch (_) {
                  // Failed to fetch listener data
                }
              }

              if (mounted) {
                setState(() {
                  _matchedListener = ListenerProfile(
                    id: lId,
                    name:
                        request.listenerHandle ??
                        userData['handle'] ??
                        'Listener',
                    rating: (userData['rating'] ?? 4.8).toDouble(),
                    acceptanceRate: (userData['acceptanceRate'] ?? 0.9)
                        .toDouble(),
                    totalCalls: (userData['totalCalls'] ?? 24).toInt(),
                    isOnline: userData['isOnline'] ?? true,
                    topics: [request.topic],
                    bio:
                        userData['bio'] ?? 'Experienced listener ready to help',
                  );
                  _matchFound = true;
                });
              }
            }
          },

          onError: (_) {},
          onDone: () {},
        );
  }

  void _onConnect() async {
    // Set request status to 'connected' - both users enter call simultaneously
    try {
      // Stop listening to this request as we are connecting
      _requestSubscription?.cancel();
      await _requestService.connectRequest(widget.requestId);
    } catch (_) {
      // connectRequest failed
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(requestId: widget.requestId),
      ),
    );

    if (mounted) {
      // Forward the result to Home
      Navigator.of(context).pop(result);
    }
  }

  void _onSkip() async {
    // Cancel current request and create a new one
    await _requestService.cancelRequest(widget.requestId);
    if (mounted) {
      Navigator.of(context).pop(); // Go back to home to create new request
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _controller.dispose();
    _requestSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _matchFound ? _buildMatchProfile() : _buildScanningRadar(),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningRadar() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            _buildRipple(100),
            _buildRipple(150),
            _buildRipple(200),
            const Icon(Icons.mic, size: 50, color: Colors.white),
          ],
        ),
        const SizedBox(height: 48),
        Text(
          "Scanning for top-rated listeners...",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          "Our AI is finding the best match for you...",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMatchProfile() {
    if (_matchedListener == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Match Found!",
            style: TextStyle(
              color: MidnightTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 32),

          // Profile Image
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MidnightTheme.secondaryColor, width: 2),
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: MidnightTheme.surfaceColor,
              child: const Icon(Icons.person, size: 60, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),

          // Name and Stats
          Text(
            _matchedListener!.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                "${_matchedListener!.rating}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                " (${_matchedListener!.totalCalls} sessions)",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Bio / Tags
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MidnightTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              "\"${_matchedListener!.bio}\"",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          const Spacer(),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onSkip,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[300],
                    side: BorderSide(color: Colors.red[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text("Skip"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _onConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MidnightTheme.primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text("Connect"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRipple(double size) {
    return ScaleTransition(
      scale: Tween(begin: 0.8, end: 1.2).animate(_controller),
      child: FadeTransition(
        opacity: Tween(begin: 0.5, end: 0.0).animate(_controller),
        child: Container(
          width: size * 2,
          height: size * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: MidnightTheme.primaryColor.withOpacity(0.5),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
