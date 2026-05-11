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
  late Future<List<SessionModel>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _sessionService.getSessions();
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
      body: FutureBuilder<List<SessionModel>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: MidnightTheme.primaryColor));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No session history found.", style: TextStyle(color: Colors.grey)));
          }

          final sessions = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              return _buildHistoryItem(sessions[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(SessionModel session) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final formattedDate = dateFormat.format(session.date);
    
    // Earnings (Green) vs Cost (Standard/White)
    final isEarnings = session.isListenerSession;
    final amountColor = isEarnings ? const Color(0xFF00E676) : Colors.white;
    final amountPrefix = isEarnings ? "+ " : "- ";

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
                      icon: const Icon(Icons.favorite_border, color: MidnightTheme.primaryColor, size: 20),
                      onPressed: () async {
                        await ConnectionService().addToStayConnected(
                          listenerId: session.partnerId,
                          listenerHandle: session.partnerName,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${session.partnerName} added to Stay Connected")),
                          );
                        }
                      },
                    ),
                  Text(
                    "$amountPrefix₹${session.amount.toStringAsFixed(0)}", 
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
