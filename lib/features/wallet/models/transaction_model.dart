import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isCredit;
  final String status;
  final String? requestId;

  WalletTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isCredit,
    this.status = 'success',
    this.requestId,
  });

  factory WalletTransaction.fromMap(String id, Map<String, dynamic> map) {
    return WalletTransaction(
      id: id,
      title: map['title'] ?? 'Transaction',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: map['date'] is Timestamp 
          ? (map['date'] as Timestamp).toDate() 
          : (DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now()),
      isCredit: map['isCredit'] ?? false,
      status: map['status'] ?? 'success',
      requestId: map['requestId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'date': date,
      'isCredit': isCredit,
      'status': status,
      'requestId': requestId,
    };
  }
}
