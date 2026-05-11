import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/transaction_model.dart';
import '../../../core/constants.dart';

class WalletService extends ChangeNotifier {
  static final WalletService _instance = WalletService._internal();

  factory WalletService() {
    return _instance;
  }

  WalletService._internal() {
    _initializeRazorpay();
    _listenToWallet();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late Razorpay _razorpay;
  double _balance = 0.0;
  List<WalletTransaction> _transactions = [];
  StreamSubscription<User?>? _authSub;
  StreamSubscription? _balanceSub;
  StreamSubscription? _transactionsSub;

  double get balance => _balance;
  List<WalletTransaction> get transactions => List.unmodifiable(_transactions);

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _listenToWallet() {
    _authSub = _auth.authStateChanges().listen((user) {
      _balanceSub?.cancel();
      _transactionsSub?.cancel();

      if (user != null) {
        _balanceSub = _firestore.collection('users').doc(user.uid).snapshots().listen((snapshot) {
          if (snapshot.exists) {
            _balance = (snapshot.data()?['walletBalance'] ?? 0.0).toDouble();
            notifyListeners();
          }
        });

        _transactionsSub = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .orderBy('date', descending: true)
            .snapshots()
            .listen((snapshot) {
              _transactions = snapshot.docs.map((doc) => WalletTransaction.fromMap(doc.id, doc.data())).toList();
              notifyListeners();
            });
      } else {
        _balance = 0.0;
        _transactions = [];
        notifyListeners();
      }
    });
  }

  void openCheckout(double amount) {
    var options = <String, dynamic>{
      'key': AppConstants.razorpayKey,
      'amount': (amount * 100).toInt(),
      'currency': 'INR',
      'name': 'Midnight App',
      'description': 'Wallet Top-up',
      'notes': {'userId': _auth.currentUser?.uid},
    };

    final contact = _auth.currentUser?.phoneNumber;
    final email = _auth.currentUser?.email;

    var prefill = <String, String>{};
    if (contact != null && contact.isNotEmpty) prefill['contact'] = contact;
    if (email != null && email.isNotEmpty) prefill['email'] = email;
    if (prefill.isNotEmpty) options['prefill'] = prefill;

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay Error: $e');
      onPaymentError?.call("Failed to open payment gateway. Please try again.");
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    notifyListeners();
  }

  void Function(String message)? onPaymentError;

  void _handlePaymentError(PaymentFailureResponse response) {
    final message = response.message ?? "Payment failed. Please try again.";
    debugPrint('Razorpay payment error: $message');
    onPaymentError?.call(message);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  Future<void> withdraw(double amount) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_balance < amount) return;

    // Withdrawal is handled by Cloud Function to ensure safety.
    // We just set a flag or trigger a function call.
    // For now, we use a simple placeholder that would be a secure call.
    debugPrint("Withdrawal of $amount requested for ${user.uid}");
  }

  Future<bool> holdFunds(double amount) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      bool success = false;
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          final balance = (userDoc.data()?['walletBalance'] ?? 0.0).toDouble();
          final held = (userDoc.data()?['heldBalance'] ?? 0.0).toDouble();

          if (balance - held >= amount) {
            transaction.update(userRef, {'heldBalance': held + amount});
            success = true;
          }
        }
      });
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<void> releaseHeldFunds(double amount) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          final held = (userDoc.data()?['heldBalance'] ?? 0.0).toDouble();
          transaction.update(userRef, {'heldBalance': max(0.0, held - amount)});
        }
      });
    } catch (e) {
      debugPrint('Error releasing funds: $e');
    }
  }

  Future<bool> makePaymentAndCompleteCall({
    required double amount,
    required String description,
    required String requestId,
    required int rating,
    required int tip,
  }) async {
    if (amount < 0 || tip < 0 || tip > 1000 || rating < 0 || rating > 5) return false;

    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      bool success = false;
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(user.uid);
        final requestRef = _firestore.collection('requests').doc(requestId);

        final userDoc = await transaction.get(userRef);
        final requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) return;
        final requestData = requestDoc.data() as Map<String, dynamic>;
        if (requestData['status'] != 'ending') return;

        if (!userDoc.exists) return;
        final currentBalance = (userDoc.data()?['walletBalance'] ?? 0.0).toDouble();
        if (currentBalance < amount) return;

        final held = (userDoc.data()?['heldBalance'] ?? 0.0).toDouble();
        transaction.update(userRef, {
          'walletBalance': currentBalance - amount,
          'heldBalance': (held - AppConstants.sessionCost).clamp(0.0, double.infinity),
        });

        transaction.update(requestRef, {
          'status': 'completed',
          'isPaid': true,
          'rating': rating > 0 ? rating : null,
          'tip': tip,
          'completedAt': FieldValue.serverTimestamp(),
        });

        success = true;
      });
      return success;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _balanceSub?.cancel();
    _transactionsSub?.cancel();
    _razorpay.clear();
    super.dispose();
  }
}
