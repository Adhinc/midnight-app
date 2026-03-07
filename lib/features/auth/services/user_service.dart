import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final CollectionReference _usersCollection = 
      FirebaseFirestore.instance.collection('users');

  // Create User in Firestore
  Future<void> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());
    } catch (e) {
      throw Exception("Failed to create user profile: $e");
    }
  }

  // Get User Profile
  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception("Failed to fetch user profile: $e");
    }
  }

  // Update Listener Status
  Future<void> updateListenerStatus(String uid, bool isOnline) async {
    try {
      // Using set with merge is sometimes more robust than update if document existence is flaky
      await _usersCollection.doc(uid).set({'isOnline': isOnline}, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Failed to update status: $e");
    }
  }
}
