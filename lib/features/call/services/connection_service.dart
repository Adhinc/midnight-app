import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add a listener to 'Stay Connected' list
  Future<void> addToStayConnected({
    required String listenerId,
    required String listenerHandle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('stay_connected')
        .doc(listenerId)
        .set({
      'listenerId': listenerId,
      'listenerHandle': listenerHandle,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  // Remove a listener from 'Stay Connected' list
  Future<void> removeFromStayConnected(String listenerId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('stay_connected')
        .doc(listenerId)
        .delete();
  }

  // Stream of saved listeners with their current online status
  Stream<List<Map<String, dynamic>>> streamStayConnectedListeners() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // We first get the list of saved IDs
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('stay_connected')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final ids = snapshot.docs.map((d) => d.id).toList();
      final Map<String, String> handles = {};
      for (var d in snapshot.docs) {
        handles[d.id] = (d.data() as Map<String, dynamic>)['listenerHandle'] ?? 'Listener';
      }

      if (ids.isEmpty) return [];

      // Fetch all listeners in a single batch (Firestore limit is 10)
      final usersSnapshot = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: ids.take(10).toList())
          .get();

      List<Map<String, dynamic>> listeners = [];
      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        listeners.add({
          'id': userDoc.id,
          'handle': handles[userDoc.id],
          'isOnline': userData['isOnline'] ?? false,
          'topics': userData['topics'] ?? [],
        });
      }
      return listeners;
    });
  }

  // Check if a specific listener is already in the 'Stay Connected' list
  Future<bool> isConnected(String listenerId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _db
        .collection('users')
        .doc(user.uid)
        .collection('stay_connected')
        .doc(listenerId)
        .get();
    
    return doc.exists;
  }
}
