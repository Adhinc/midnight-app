import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants.dart';
import '../models/session_model.dart';

class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<SessionModel>> getSessions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      // Fetch sessions where user was seeker OR listener
      final seekerQuery = await _firestore
          .collection('requests')
          .where('seekerId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .get();

      final listenerQuery = await _firestore
          .collection('requests')
          .where('listenerId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .get();

      final allDocs = [...seekerQuery.docs, ...listenerQuery.docs];

      final sessions = allDocs.map((doc) {
        final data = doc.data();
        final isListenerSession = data['listenerId'] == uid;
        final partnerId = isListenerSession 
            ? (data['seekerId'] ?? '') 
            : (data['listenerId'] ?? '');
        final partnerName = isListenerSession
            ? (data['seekerHandle'] ?? 'Anonymous')
            : (data['listenerHandle'] ?? 'Anonymous');
        
        final tip = (data['tip'] ?? 0).toInt();
        
        // Listener earns: basePay + tip
        // Seeker pays: sessionCost + tip
        final amount = isListenerSession
            ? (AppConstants.sessionBasePay + tip).toDouble()
            : (AppConstants.sessionCost + tip).toDouble();

        return SessionModel(
          id: doc.id,
          partnerId: partnerId,
          partnerName: partnerName,
          date: _parseDate(data['completedAt'] ?? data['timestamp']),
          duration: _parseDuration(data['connectedAt'], data['completedAt']),
          rating: (data['rating'] ?? 0).toDouble(),
          amount: amount,
          isListenerSession: isListenerSession,
        );
      }).toList();

      // Sort by date descending
      sessions.sort((a, b) => b.date.compareTo(a.date));
      return sessions;
    } catch (e) {
      debugPrint("SessionService Error: $e");
      throw Exception("Failed to load session history. Please check your connection.");
    }
  }

  DateTime _parseDate(dynamic dateVal) {
    if (dateVal == null) return DateTime.now();
    if (dateVal is Timestamp) return dateVal.toDate();
    return DateTime.tryParse(dateVal.toString()) ?? DateTime.now();
  }

  Duration _parseDuration(dynamic connectedAt, dynamic completedAt) {
    if (connectedAt == null || completedAt == null) return Duration.zero;
    try {
      DateTime start = _parseDate(connectedAt);
      DateTime end = _parseDate(completedAt);
      return end.difference(start);
    } catch (_) {
      return Duration.zero;
    }
  }
}
