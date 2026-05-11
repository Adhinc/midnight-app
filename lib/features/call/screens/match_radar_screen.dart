import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import 'call_screen.dart';
import '../models/listener_model.dart';
import '../models/help_request.dart';
import '../services/request_service.dart';
import '../../wallet/services/wallet_service.dart';
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
        _cancelEverything();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No listeners available. Please try again.")),
        );
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _cancelEverything() async {
    _requestSubscription?.cancel();
    await _requestService.cancelRequest(widget.requestId);
    await WalletService().releaseHeldFunds(AppConstants.sessionCost.toDouble());
  }

  void _startScanning() {
    _requestSubscription = _requestService
        .streamRequestById(widget.requestId)
        .listen(
          (request) async {
            if (request == null || !mounted) return;

            // Trigger match profile for pending, accepted, or connected
            if (['pending', 'accepted', 'connected'].contains(request.status) && !_matchFound) {
              _matchFound = true; // Mark as found to stop scanning UI
              
              String lId = request.listenerId ?? '';
              Map<String, dynamic> userData = {};
              if (lId.isNotEmpty) {
                try {
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(lId)
                      .get();
                  userData = userDoc.data() ?? {};
                } catch (_) {}
              }

              if (mounted) {
                setState(() {
                  _matchedListener = ListenerProfile(
                    id: lId,
                    name: request.listenerHandle ?? userData['handle'] ?? 'Listener',
                    rating: (userData['rating'] ?? 0.0).toDouble(), // No fake stats
                    acceptanceRate: (userData['acceptanceRate'] ?? 1.0).toDouble(),
                    totalCalls: (userData['totalCalls'] ?? 0).toInt(), // No fake stats
                    isOnline: userData['isOnline'] ?? true,
                    topics: [request.topic],
                    bio: userData['bio'] ?? 'Ready to listen and support you.',
                  );
                });
              }
            }
          },
          onError: (_) {},
        );
  }

  void _onConnect() async {
    try {
      _requestSubscription?.cancel();
      await _requestService.connectRequest(widget.requestId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection failed: $e")),
        );
      }
      _startScanning(); // Resume scanning if it failed
      return;
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(requestId: widget.requestId),
      ),
    );

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  void _onSkip() async {
    await _cancelEverything();
    if (mounted) {
      Navigator.of(context).pop();
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _cancelEverything();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
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
                  onPressed: _onSkip,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: MidnightTheme.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: MidnightTheme.primaryColor, width: 2),
              ),
              child: const Icon(Icons.radar, color: MidnightTheme.primaryColor, size: 40),
            ),
          ],
        ),
        const SizedBox(height: 48),
        const Text(
          "Finding your listener...",
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "Matching you with the best available support",
          style: TextStyle(color: Colors.grey),
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
          StreamBuilder<HelpRequest?>(
            stream: _requestService.streamRequestById(widget.requestId),
            builder: (context, snapshot) {
              final status = snapshot.data?.status ?? 'accepted';
              String statusText = "Match Found!";
              if (status == 'pending') statusText = "Listener found! Waiting...";
              if (status == 'accepted') statusText = "Listener is ready!";
              
              return Text(
                statusText,
                style: const TextStyle(color: MidnightTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
              );
            }
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: MidnightTheme.secondaryColor, width: 2)),
            child: CircleAvatar(radius: 60, backgroundColor: MidnightTheme.surfaceColor, child: const Icon(Icons.person, size: 60, color: Colors.white)),
          ),
          const SizedBox(height: 24),
          Text(_matchedListener!.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text("${_matchedListener!.rating == 0 ? 'New' : _matchedListener!.rating}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              if (_matchedListener!.totalCalls > 0) Text(" (${_matchedListener!.totalCalls} sessions)", style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: MidnightTheme.surfaceColor, borderRadius: BorderRadius.circular(16)),
            child: Text("\"${_matchedListener!.bio}\"", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onSkip,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red[300], side: BorderSide(color: Colors.red[300]!), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: const Text("Skip"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _onConnect,
                  style: ElevatedButton.styleFrom(backgroundColor: MidnightTheme.primaryColor, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
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
            border: Border.all(color: MidnightTheme.primaryColor.withOpacity(0.5), width: 2),
          ),
        ),
      ),
    );
  }
}
