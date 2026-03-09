import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/help_request.dart';

class RequestService {
  final CollectionReference _requestsCollection = FirebaseFirestore.instance
      .collection('requests');

  // Create a new help request
  Future<String> createRequest(HelpRequest request) async {
    try {
      // 1. Cancel any existing open requests for this seeker prevents duplicates
      final existingOpen = await _requestsCollection
          .where('seekerId', isEqualTo: request.seekerId)
          .where('status', isEqualTo: 'open')
          .get();

      if (existingOpen.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in existingOpen.docs) {
          batch.update(doc.reference, {'status': 'cancelled'});
        }
        await batch.commit();
      }

      // 2. Create the new request
      final docRef = await _requestsCollection.add(request.toMap());
      // Update the document with its own ID
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      throw Exception("Failed to create request: $e");
    }
  }

  Stream<List<HelpRequest>> streamOpenRequests(List<String> allowedTopics) {
    if (allowedTopics.isEmpty) {
      // If the listener has no topics selected, they shouldn't see any requests
      return Stream.value([]);
    }

    // Firestore 'whereIn' supports up to 10 items.
    // Assuming available topics are less than 10.
    return _requestsCollection
        .where('status', isEqualTo: 'open')
        .where('topic', whereIn: allowedTopics)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) =>
                    HelpRequest.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();
        });
  }

  // Stream a specific request by ID (for Seekers waiting for match)
  Stream<HelpRequest?> streamRequestById(String requestId) {
    return _requestsCollection.doc(requestId).snapshots().map((doc) {
      if (doc.exists) {
        return HelpRequest.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  // Get a single request by ID (one-time fetch)
  Future<HelpRequest?> getRequestById(String requestId) async {
    try {
      final snapshot = await _requestsCollection.doc(requestId).get();
      if (snapshot.exists) {
        return HelpRequest.fromMap(snapshot.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception("Failed to get request: $e");
    }
  }

  // Claim a request (Listener clicks on dashboard - sets to 'pending')
  Future<void> claimRequest(
    String requestId,
    String listenerId,
    String listenerHandle,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = _requestsCollection.doc(requestId);
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception("Request does not exist");
        }

        final data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] != 'open') {
          throw Exception("Request is already ${data['status']}");
        }

        transaction.update(docRef, {
          'status': 'pending',
          'listenerId': listenerId,
          'listenerHandle': listenerHandle,
        });
      });
    } catch (e) {
      throw Exception("Failed to claim request: $e");
    }
  }

  // Accept a request (Listener clicks "Accept & Earn" - sets to 'accepted')
  Future<void> acceptRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = _requestsCollection.doc(requestId);
        final snapshot = await transaction.get(docRef);
        final data = snapshot.data() as Map<String, dynamic>;

        // Only allow accepting if currently pending
        if (data['status'] == 'pending') {
          transaction.update(docRef, {'status': 'accepted'});
        }
      });
    } catch (e) {
      throw Exception("Failed to accept request: $e");
    }
  }

  // Connect to call (Seeker clicks "Connect" - sets to 'connected')
  Future<void> connectRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = _requestsCollection.doc(requestId);
        final snapshot = await transaction.get(docRef);
        final data = snapshot.data() as Map<String, dynamic>;

        // Only allow connecting if currently accepted
        if (data['status'] == 'accepted') {
          transaction.update(docRef, {
            'status': 'connected',
            'connectedAt': DateTime.now().toIso8601String(),
          });
        }
      });
    } catch (e) {
      throw Exception("Failed to connect request: $e");
    }
  }

  // End call (Either user clicks end - sets to 'ending')
  Future<void> endCall(String requestId) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = _requestsCollection.doc(requestId);
        final snapshot = await transaction.get(docRef);
        final data = snapshot.data() as Map<String, dynamic>;

        // Only allow ending if currently connected
        if (data['status'] == 'connected') {
          transaction.update(docRef, {'status': 'ending'});
        }
      });
    } catch (e) {
      throw Exception("Failed to end call: $e");
    }
  }

  // Complete call (Seeker confirms rating/payment - sets to 'completed')
  Future<void> completeCall(String requestId, int rating, int tip) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = _requestsCollection.doc(requestId);
        final snapshot = await transaction.get(docRef);
        final data = snapshot.data() as Map<String, dynamic>;

        // Only allow completion from 'ending' state
        if (data['status'] == 'ending') {
          transaction.update(docRef, {
            'status': 'completed',
            'rating': rating > 0 ? rating : null, // Fix #7: Only store if > 0
            'tip': tip,
            'completedAt': DateTime.now().toIso8601String(),
          });
        }
      });
    } catch (e) {
      throw Exception("Failed to complete call: $e");
    }
  }

  // Cancel a request
  Future<void> cancelRequest(String requestId) async {
    try {
      await _requestsCollection.doc(requestId).update({'status': 'cancelled'});
    } catch (e) {
      throw Exception("Failed to cancel request: $e");
    }
  }

  // Get listener stats (session count and average rating)
  Future<Map<String, dynamic>> getListenerStats(String listenerId) async {
    try {
      final querySnapshot = await _requestsCollection
          .where('listenerId', isEqualTo: listenerId)
          .where('status', isEqualTo: 'completed')
          .get();

      final totalSessions = querySnapshot.docs.length;
      if (totalSessions == 0) {
        return {'sessions': 0, 'rating': 0.0};
      }

      double totalRating = 0;
      int ratedSessions = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('rating') && data['rating'] != null) {
          totalRating += (data['rating'] as num).toDouble();
          ratedSessions++;
        }
      }

      final averageRating = ratedSessions > 0
          ? totalRating / ratedSessions
          : 0.0;

      return {
        'sessions': totalSessions,
        'rating': double.parse(averageRating.toStringAsFixed(1)),
      };
    } catch (e) {
      return {'sessions': 0, 'rating': 0.0};
    }
  }

  // Get completed requests for a listener (ordered by timestamp descending)
  Future<List<HelpRequest>> getCompletedRequestsForListener(
    String listenerId,
  ) async {
    try {
      final querySnapshot = await _requestsCollection
          .where('listenerId', isEqualTo: listenerId)
          .where('status', isEqualTo: 'completed')
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => HelpRequest.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Index missing, try client-side sorting fallback
      // If index is missing, try client-side sorting (less efficient but works without index deployment immediately)
      try {
        final querySnapshot = await _requestsCollection
            .where('listenerId', isEqualTo: listenerId)
            .where('status', isEqualTo: 'completed')
            .get();

        final requests = querySnapshot.docs
            .map(
              (doc) => HelpRequest.fromMap(doc.data() as Map<String, dynamic>),
            )
            .toList();

        requests.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return requests;
      } catch (e2) {
        return [];
      }
    }
  }
}
