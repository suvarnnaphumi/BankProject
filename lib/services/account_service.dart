import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account_model.dart';
import 'auth_service.dart';
import 'bank_exception.dart';

/// ข้อมูลบัญชีผู้ใช้: ดูยอดเงิน, ค้นหาบัญชี, รูปโปรไฟล์
///
/// โครงสร้างใน Firestore
///   users/{อีเมล} -> uid, email, accountNumber, name, balance, savingsBalance,
///                    createdAt, photo (รูปโปรไฟล์ base64 ไม่มีก็ได้)
///   (อีเมล/รหัสผ่านเก็บใน Firebase Authentication ไม่ได้เก็บใน Firestore)
class AccountService {
  AccountService._();
  static final instance = AccountService._();

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection(AccountModel.collectionName);

  /// ฟังข้อมูลบัญชีแบบ real-time (ยอดเงินเปลี่ยนเมื่อไหร่ หน้าจออัปเดตเอง)
  Stream<AccountModel> watchAccount(String userId) => _users
      .doc(userId)
      .snapshots()
      .where((doc) => doc.exists) // ข้ามตอนที่ document ถูกลบ (ลบบัญชี)
      .map((doc) => AccountModel.fromJson(doc.data()!));

  /// หา document ของ user จากเลขบัญชี (null ถ้าไม่มีบัญชีนี้)
  Future<DocumentSnapshot<Map<String, dynamic>>?> _docByAccountNumber(
    String accountNumber,
  ) async {
    final result = await _users
        .where('accountNumber', isEqualTo: accountNumber)
        .limit(1)
        .get();
    return result.docs.isEmpty ? null : result.docs.first;
  }

  /// ที่อยู่ของ document จากเลขบัญชี ใช้ใน service โอน/ถอน/ออม (null ถ้าไม่มีบัญชีนี้)
  Future<DocumentReference<Map<String, dynamic>>?> refByAccountNumber(
    String accountNumber,
  ) async => (await _docByAccountNumber(accountNumber))?.reference;

  /// หาเจ้าของบัญชีจากเลขบัญชี (null ถ้าไม่มีบัญชีนี้)
  Future<AccountModel?> findAccount(String accountNumber) async {
    final doc = await _docByAccountNumber(accountNumber);
    return doc == null ? null : AccountModel.fromJson(doc.data()!);
  }

  // ---------------------------------------------------------------- รูปโปรไฟล์

  /// เก็บรูปโปรไฟล์เป็นข้อความ base64 ใน document ของผู้ใช้เลย
  /// (ไม่ใช้ Firebase Storage เพราะต้องเปิดแพ็กเกจเสียเงิน)
  /// Firestore รับได้ไม่เกิน 1MB ต่อ document จึงต้องย่อรูปให้เล็กก่อนส่งมา
  Future<void> updateProfilePhoto(Uint8List bytes) async {
    if (bytes.length > 500 * 1024) {
      throw BankException('รูปใหญ่เกินไป กรุณาเลือกรูปอื่น');
    }
    await _users.doc(AuthService.instance.currentUserId).update({
      'photo': base64Encode(bytes),
    });
  }

  Future<void> removeProfilePhoto() async {
    await _users.doc(AuthService.instance.currentUserId).update({
      'photo': FieldValue.delete(),
    });
  }
}
