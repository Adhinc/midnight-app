import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../call/services/request_service.dart';
import '../../call/models/help_request.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class RatingHistoryScreen extends StatefulWidget {
  const RatingHistoryScreen({super.key});

  @override
  State<RatingHistoryScreen> createState() => _RatingHistoryScreenState();
}

class _RatingHistoryScreenState extends State<RatingHistoryScreen> {
  final RequestService _requestService = RequestService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Map<String, dynamic> _stats = {'sessions': 0, 'rating': 0.0};
  List<HelpRequest> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    if (user != null) {
      final stats = await _requestService.getListenerStats(user.uid);
      // Fetch ONLY rated sessions from server
      final reviews = await _requestService.getCompletedRequestsForListener(user.uid, onlyRated: true);
      
      if (mounted) {
        setState(() {
          _stats = stats;
          _reviews = reviews;
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
        title: const Text("Karma & Reviews", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: MidnightTheme.primaryColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: MidnightTheme.primaryColor))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildOverallRating(),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Recent Ratings", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    if (_reviews.isEmpty)
                       Padding(
                         padding: const EdgeInsets.only(top: 20),
                         child: Text("No ratings yet", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                       )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) => _buildReviewCard(context, _reviews[index]),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOverallRating() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MidnightTheme.primaryColor.withOpacity(0.2), MidnightTheme.surfaceColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MidnightTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text("Overall Rating", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text("${_stats['rating']}", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Icon(
                index < (_stats['rating'] as num).round() ? Icons.star : Icons.star_border, 
                color: Colors.amber, 
                size: 24
              );
            }),
          ),
          const SizedBox(height: 8),
          Text("Based on ${_stats['sessions']} sessions", style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, HelpRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MidnightTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    child: const Icon(Icons.person, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text("Seeker (Anonymous)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(timeago.format(request.timestamp), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) => Icon(
              Icons.star, 
              color: i < (request.rating ?? 0) ? Colors.amber : Colors.grey, 
              size: 16
            )),
          ),
        ],
      ),
    );
  }
}
