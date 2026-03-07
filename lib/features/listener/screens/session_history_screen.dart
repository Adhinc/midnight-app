import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../call/services/request_service.dart';
import '../../call/models/help_request.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  final RequestService _requestService = RequestService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<HelpRequest> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final user = _auth.currentUser;
    if (user != null) {
      final sessions = await _requestService.getCompletedRequestsForListener(user.uid);
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      appBar: AppBar(
        title: const Text("Session History", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: MidnightTheme.primaryColor))
          : _sessions.isEmpty 
              ? Center(child: Text("No completed sessions yet", style: TextStyle(color: Colors.white.withOpacity(0.5))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    return _buildSessionCard(context, _sessions[index]);
                  },
                ),
    );
  }

  Widget _buildSessionCard(BuildContext context, HelpRequest session) {
    final pay = 30 + (session.tip ?? 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MidnightTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Session #${session.id.substring(0, 5).toUpperCase()}", // Short ID
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MidnightTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Completed",
                  style: const TextStyle(color: MidnightTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(session.seekerHandle, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM d, y • h:mm a').format(session.timestamp), 
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Earnings", style: TextStyle(color: Colors.white70)),
               Text("₹$pay.00", style: const TextStyle(color: MidnightTheme.secondaryColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
