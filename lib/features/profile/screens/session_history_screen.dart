import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../profile/models/session_model.dart';
import '../../profile/services/session_service.dart';
import '../../call/services/connection_service.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  final SessionService _sessionService = SessionService();
  final ConnectionService _connectionService = ConnectionService();
  List<SessionModel> _sessions = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _connectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final sessions = await _sessionService.getSessions();
      
      // Load connected status for all partners in seeker sessions
      for (var session in sessions) {
        if (!session.isListenerSession) {
          final connected = await _connectionService.isConnected(session.partnerId);
          if (connected) {
            _connectedIds.add(session.partnerId);
          }
        }
      }

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst("Exception: ", "");
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightTheme.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Session History", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: MidnightTheme.primaryColor,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: MidnightTheme.primaryColor));
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text("Try Again")),
            ],
          ),
        ),
      );
    }

    if (_sessions.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: const Center(child: Text("No session history found.", style: TextStyle(color: Colors.grey))),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        return _buildHistoryItem(_sessions[index]);
      },
    );
  }

  Widget _buildHistoryItem(SessionModel session) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final formattedDate = dateFormat.format(session.date);
    
    // Earnings (Green) vs Cost (Standard/White)
    final isEarnings = session.isListenerSession;
    final amountColor = isEarnings ? const Color(0xFF00E676) : Colors.white;
    final amountPrefix = isEarnings ? "+ " : "- ";
    final isConnected = _connectedIds.contains(session.partnerId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MidnightTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.1),
            child: Icon(
              session.isListenerSession ? Icons.person_outline : Icons.headset_mic, 
              color: Colors.white
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.partnerName, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate, 
                  style: const TextStyle(color: Colors.grey, fontSize: 12)
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  if (!session.isListenerSession)
                    IconButton(
                      icon: Icon(
                        isConnected ? Icons.favorite : Icons.favorite_border, 
                        color: MidnightTheme.primaryColor, 
                        size: 20
                      ),
                      onPressed: isConnected ? null : () async {
                        await _connectionService.addToStayConnected(
                          listenerId: session.partnerId,
                          listenerHandle: session.partnerName,
                        );
                        if (mounted) {
                          setState(() => _connectedIds.add(session.partnerId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${session.partnerName} added to Stay Connected")),
                          );
                        }
                      },
                    ),
                  Text(
                    "$amountPrefix₹${session.amount.toStringAsFixed(2)}", 
                    style: TextStyle(color: amountColor, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                   Text(
                    "${session.duration.inMinutes} min", 
                    style: const TextStyle(color: Colors.grey, fontSize: 12)
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(5, (i) => Icon(
                    Icons.star, 
                    size: 12, 
                    color: i < session.rating ? Colors.amber : Colors.grey.withOpacity(0.3)
                  )),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}
