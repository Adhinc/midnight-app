import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "An unknown error occurred";
    }
  }

  Future<User?> signUpWithEmail(
    String email,
    String password, {
    String? handle,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update Display Name immediately
      if (handle != null) {
        await userCredential.user?.updateDisplayName(handle);
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "An unknown error occurred";
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
