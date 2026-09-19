/// ข้อมูลบัญชีผู้ใช้ 1 คน (เก็บใน Firestore collection 'users', ID ของ document = อีเมล)
class AccountModel {
  final String uid; // uid จาก Firebase Authentication
  final String email;
  final String accountNumber; // เลขบัญชี 10 หลัก
  final String name; // ชื่อ-นามสกุล
  final double balance; // ยอดเงินคงเหลือ

  static const collectionName = 'users';

  AccountModel({
    required this.uid,
    required this.email,
    required this.accountNumber,
    required this.name,
    required this.balance,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      accountNumber: json['accountNumber'] ?? '',
      name: json['name'] ?? '',
      // ใช้ .toDouble() เสมอ ไม่ว่าค่าจาก Firestore จะเป็น int หรือ double
      balance: (json['balance'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'accountNumber': accountNumber,
      'name': name,
      'balance': balance,
    };
  }
}
