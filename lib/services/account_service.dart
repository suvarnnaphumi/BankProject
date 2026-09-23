import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account_model.dart';
import 'auth_service.dart';
import 'bank_exception.dart';

/// ข้อมูลบัญชีผู้ใช้ใน firebase: ดูยอดเงิน, ค้นหาบัญชี, รูปโปรไฟล์
class AccountService {
  AccountService._();
  static final instance = AccountService._();

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection(AccountModel.collectionName);

  /// อัพเดตข้อมูลบัญชีแบบ real-time
  Stream<AccountModel> watchAccount(String userId) => _users
      .doc(userId)
      .snapshots()
      .where((doc) => doc.exists)
      .map((doc) => AccountModel.fromJson(doc.data()!));

  Future<DocumentSnapshot<Map<String, dynamic>>?> _docByAccountNumber(
    String accountNumber,
  ) async {
    final result = await _users
        .where('accountNumber', isEqualTo: accountNumber)
        .limit(1)
        .get();
    return result.docs.isEmpty ? null : result.docs.first;
  }

  Future<DocumentReference<Map<String, dynamic>>?> refByAccountNumber(
    String accountNumber,
  ) async => (await _docByAccountNumber(accountNumber))?.reference;

  Future<AccountModel?> findAccount(String accountNumber) async {
    final doc = await _docByAccountNumber(accountNumber);
    return doc == null ? null : AccountModel.fromJson(doc.data()!);
  }

  /// เก็บรูปโปรไฟล์แล้วแปลเป็นข้อความ base64 ใน document ของผู้ใช้
  Future<void> updateProfilePhoto(Uint8List bytes) async {
    if (bytes.length > 500 * 1024) {
      throw BankException('รูปใหญ่เกินไป กรุณาเลือกรูปอื่น');
    }
    await _users.doc(AuthService.instance.currentUserId).update({
      'photo': base64Encode(bytes),
    });
  }

  /// ลบรูปโปรไฟล์
  Future<void> removeProfilePhoto() async {
    await _users.doc(AuthService.instance.currentUserId).update({
      'photo': FieldValue.delete(),
    });
  }
}
