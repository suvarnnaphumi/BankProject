import 'package:cloud_firestore/cloud_firestore.dart';

/// รายการธุรกรรม 1 รายการ เก็บใน transactions
class TransactionModel {
  final String type;
  final String from;
  final String fromName;
  final String? to; // เลขบัญชีปลายทาง (ถอนเงินจะเป็น null)
  final String? toName;
  final double amount;
  final DateTime createdAt;

  static const collectionName = 'transactions';

  TransactionModel({
    required this.type,
    required this.from,
    required this.fromName,
    this.to,
    this.toName,
    required this.amount,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final ts = json['createdAt'];
    return TransactionModel(
      type: json['type'] ?? '',
      from: json['from'] ?? '',
      fromName: json['fromName'] ?? '',
      to: json['to'],
      toName: json['toName'],
      amount: (json['amount'] as num? ?? 0).toDouble(),
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'from': from,
      'fromName': fromName,
      'to': to,
      'toName': toName,
      'amount': amount,

      // (?to = ใส่ to ลงไปเฉพาะตอนที่ไม่เป็น null เช่น ถอนเงินจะมีแค่ [from])
      'participants': [from, ?to],
      // ใช้เวลาของ server แทนเวลาในเครื่อง
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
