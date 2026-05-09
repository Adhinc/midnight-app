import 'dart:async';
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
  List<Transaction> _transactions = [];
  StreamSubscription<User?>? _authSub;
  StreamSubscription? _balanceSub;
  StreamSubscription? _transactionsSub;

  double get balance => _balance;
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // Listen to Firestore real-time updates
  void _listenToWallet() {
    _authSub = _auth.authStateChanges().listen((user) {
      // Cancel previous listeners on auth change
      _balanceSub?.cancel();
      _transactionsSub?.cancel();

      if (user != null) {
        // Listen to User Document for Balance
        _balanceSub = _firestore.collection('users').doc(user.uid).snapshots().listen((
          snapshot,
        ) {
          if (snapshot.exists) {
            _balance = (snapshot.data()?['walletBalance'] ?? 0.0).toDouble();
            notifyListeners();
          }
        });

        // Listen to Transactions Subcollection
        _transactionsSub = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .orderBy('date', descending: true)
            .snapshots()
            .listen((snapshot) {
              _transactions = snapshot.docs.map((doc) {
                return Transaction(
                  id: doc.id,
                  title: doc['title'],
                  amount: (doc['amount'] ?? 0.0).toDouble(),
                  date: (doc['date'] as Timestamp).toDate(),
                  isCredit: doc['isCredit'],
                );
              }).toList();
              notifyListeners();
            });
      } else {
        _balance = 0.0;
        _transactions = [];
        notifyListeners();
      }
    });
  }

  // Open Razorpay Checkout
  void openCheckout(double amount) {
    var options = <String, dynamic>{
      'key': AppConstants.razorpayKey,
      'amount': (amount * 100).toInt(), // Amount in paise
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

    if (prefill.isNotEmpty) {
      options['prefill'] = prefill;
    }

    try {
      _razorpay.open(options);
    } catch (e) {
      // Razorpay checkout error
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Payment Successful - No longer update balance from here!
    // The balance will be updated by the Cloud Function webhook securely.
    // Notify UI that verification is pending
    notifyListeners();
  }

  // Callback for UI to listen to payment errors
  void Function(String message)? onPaymentError;

  void _handlePaymentError(PaymentFailureResponse response) {
    final message = response.message ?? "Payment failed. Please try again.";
    debugPrint('Razorpay payment error: $message');
    onPaymentError?.call(message);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // External wallet selected
  }

  Future<bool> addEarnings(
    double amount,
    String description,
    String requestId,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('addEarnings FAILED: user is null');
      return false;
    }

    try {
      bool actuallyPaid = false;
      await _firestore.runTransaction((transaction) async {
        // 1. Check if already paid
        final requestRef = _firestore.collection('requests').doc(requestId);
        final requestDoc = await transaction.get(requestRef);

        if (requestDoc.exists) {
          final isPaid = requestDoc.data()?['isPaid'] ?? false;
          if (isPaid) {
            debugPrint('addEarnings: Already paid for request $requestId');
            return; // Already paid, abort transaction
          }
          // Mark as paid IMMEDIATELY in the same transaction
          transaction.update(requestRef, {'isPaid': true});
        }

        // 2. Update User Balance
        final userRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          transaction.set(userRef, {'walletBalance': amount});
        } else {
          final currentBalance = (userDoc.data()?['walletBalance'] ?? 0.0)
              .toDouble();
          transaction.update(userRef, {
            'walletBalance': currentBalance + amount,
          });
        }

        // 3. Add Transaction Record
        final txRef = userRef.collection('transactions').doc();
        transaction.set(txRef, {
          'id': txRef.id,
          'title': description,
          'amount': amount,
          'date': FieldValue.serverTimestamp(),
          'isCredit': true,
          'status': 'success',
          'requestId': requestId,
        });

        actuallyPaid = true;
      });
      debugPrint('addEarnings result: actuallyPaid=$actuallyPaid, amount=$amount');
      return actuallyPaid;
    } catch (e) {
      debugPrint('addEarnings ERROR: $e');
      return false;
    }
  }

  // Withdraw Funds
  Future<void> withdraw(double amount) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_balance < amount) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          final currentBalance = (userDoc.data()?['walletBalance'] ?? 0.0)
              .toDouble();
          if (currentBalance >= amount) {
            transaction.update(userRef, {
              'walletBalance': currentBalance - amount,
            });

            final txRef = userRef.collection('transactions').doc();
            transaction.set(txRef, {
              'id': txRef.id,
              'title': 'Withdrawal',
              'amount': amount,
              'date': FieldValue.serverTimestamp(),
              'isCredit': false,
              'status': 'processing', // Withdrawals usually need approval
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error withdrawing: $e');
    }
  }

  // Make Payment (for Session)
  // Returns true if payment was successful, false if insufficient balance.
  Future<bool> makePayment(double amount, String description) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      bool success = false;
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(user.uid);
        final userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          final currentBalance = (userDoc.data()?['walletBalance'] ?? 0.0)
              .toDouble();
          if (currentBalance >= amount) {
            transaction.update(userRef, {
              'walletBalance': currentBalance - amount,
            });

            final txRef = userRef.collection('transactions').doc();
            transaction.set(txRef, {
              'id': txRef.id,
              'title': description,
              'amount': amount,
              'date': FieldValue.serverTimestamp(),
              'isCredit': false,
              'status': 'success',
            });
            success = true;
          }
        }
      });
      return success;
    } catch (e) {
      return false;
    }
  }

  // Atomic payment + call completion in a single transaction
  // Returns true if successful, false if insufficient balance
  Future<bool> makePaymentAndCompleteCall({
    required double amount,
    required String description,
    required String requestId,
    required int rating,
    required int tip,
  }) async {
    // Validate inputs
    if (amount < 0 || tip < 0 || tip > 1000 || rating < 0 || rating > 5) {
      return false;
    }

    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      bool success = false;
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(user.uid);
        final requestRef = _firestore.collection('requests').doc(requestId);

        final userDoc = await transaction.get(userRef);
        final requestDoc = await transaction.get(requestRef);

        // Verify request is in 'ending' state
        if (!requestDoc.exists) return;
        final requestData = requestDoc.data() as Map<String, dynamic>;
        if (requestData['status'] != 'ending') return;

        // Check balance
        if (!userDoc.exists) return;
        final currentBalance =
            (userDoc.data()?['walletBalance'] ?? 0.0).toDouble();
        if (currentBalance < amount) return;

        // Deduct balance
        transaction.update(userRef, {
          'walletBalance': currentBalance - amount,
        });

        // Record transaction
        final txRef = userRef.collection('transactions').doc();
        transaction.set(txRef, {
          'id': txRef.id,
          'title': description,
          'amount': amount,
          'date': FieldValue.serverTimestamp(),
          'isCredit': false,
          'status': 'success',
          'requestId': requestId,
        });

        // Complete the call
        transaction.update(requestRef, {
          'status': 'completed',
          'rating': rating > 0 ? rating : null,
          'tip': tip,
          'completedAt': DateTime.now().toIso8601String(),
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
