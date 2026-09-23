import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account_model.dart';
import 'account_service.dart';
import 'bank_exception.dart';

/// สมัครสมาชิก / เข้าสู่ระบบ / ออกจากระบบ / ลบบัญชี
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  static const double startingBalance = 10000;

  final _auth = FirebaseAuth.instance;
  final _random = Random();

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection(AccountModel.collectionName);

  String? currentUserId;
  String? currentAccountNumber;

  Future<String> _generateUniqueAccountNumber() async {
    while (true) {
      final number =
          (_random.nextInt(9) + 1).toString() +
          List.generate(9, (_) => _random.nextInt(10)).join();
      final exists = await AccountService.instance.refByAccountNumber(number);
      if (exists == null) return number;
    }
  }

  /// อีเมล/รหัสผ่านเก็บใน Firebase Authentication ส่วนข้อมูลบัญชีเก็บใน Firestore
  Future<String> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw BankException(_authErrorMessage(e));
    }

    try {
      final docId = credential.user!.email!;
      final accountNumber = await _generateUniqueAccountNumber();
      final account = AccountModel(
        uid: credential.user!.uid,
        email: docId,
        accountNumber: accountNumber,
        name: name,
        balance: startingBalance,
      );
      await _users.doc(docId).set({
        ...account.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      currentUserId = docId;
      currentAccountNumber = accountNumber;
      return accountNumber;
    } catch (_) {
      await credential.user?.delete();
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw BankException(_authErrorMessage(e));
    }

    // หาข้อมูลบัญชีใน Firestore จากอีเมล
    final docId = credential.user!.email!;
    final doc = await _users.doc(docId).get();
    if (!doc.exists) {
      await _auth.signOut();
      throw BankException('ไม่พบข้อมูลบัญชีของอีเมลนี้');
    }
    currentUserId = docId;
    currentAccountNumber = doc['accountNumber'] as String;
  }

  Future<void> logout() async {
    await _auth.signOut();
    currentUserId = null;
    currentAccountNumber = null;
  }

  /// ลบบัญชีผู้ใช้ถาวร: ลบข้อมูลใน Firestore และบัญชีใน Firebase Authentication
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw BankException('กรุณาเข้าสู่ระบบใหม่อีกครั้ง');

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        throw BankException('รหัสผ่านไม่ถูกต้อง');
      }
      throw BankException(_authErrorMessage(e));
    }

    await _users.doc(currentUserId).delete();
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw BankException(_authErrorMessage(e));
    }
    currentUserId = null;
    currentAccountNumber = null;
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้สมัครไปแล้ว';
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'weak-password':
        return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัว';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'too-many-requests':
        return 'ลองเข้าสู่ระบบหลายครั้งเกินไป กรุณารอสักครู่';
      case 'network-request-failed':
        return 'เชื่อมต่ออินเทอร์เน็ตไม่ได้';
      case 'operation-not-allowed':
        return 'ยังไม่ได้เปิดใช้ Email/Password ใน Firebase Authentication';
      default:
        return 'เกิดข้อผิดพลาด: ${e.message}';
    }
  }
}
