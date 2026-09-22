import 'dart:convert';
import 'dart:typed_data';

/// ข้อมูลบัญชีผู้ใช้
class AccountModel {
  final String uid; // uid จาก Firebase Authentication
  final String email;
  final String accountNumber;
  final String name;
  final double balance;
  final double savingsBalance; // ยอดเงินในบัญชีออม (แยกจากยอดเงินหลัก)

  /// ใน Firestore เก็บเป็นข้อความ base64 แต่ในแอพแปลงกลับเป็น bytes ไว้แสดงผล
  final Uint8List? photo;

  static const collectionName = 'users';

  AccountModel({
    required this.uid,
    required this.email,
    required this.accountNumber,
    required this.name,
    required this.balance,
    this.savingsBalance = 0,
    this.photo,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    final photo = json['photo'] as String?;
    return AccountModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      accountNumber: json['accountNumber'] ?? '',
      name: json['name'] ?? '',
      // ใช้ .toDouble() เสมอ ไม่ว่าค่าจาก Firestore จะเป็น int หรือ double
      balance: (json['balance'] as num? ?? 0).toDouble(),
      // บัญชีที่สมัครก่อนมีระบบออมจะไม่มีช่องนี้ -> ถือว่าเป็น 0
      savingsBalance: (json['savingsBalance'] as num? ?? 0).toDouble(),
      photo: photo == null ? null : base64Decode(photo),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'accountNumber': accountNumber,
      'name': name,
      'balance': balance,
      'savingsBalance': savingsBalance,
      if (photo != null) 'photo': base64Encode(photo!),
    };
  }
}
