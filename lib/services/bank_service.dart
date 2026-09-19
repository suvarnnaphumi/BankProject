import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account_model.dart';
import '../models/transaction_model.dart';

/// ข้อความ error ที่จะโชว์ให้ผู้ใช้เห็นตรงๆ
class BankException implements Exception {
  final String message;
  BankException(this.message);
  @override
  String toString() => message;
}

/// โครงสร้างข้อมูลใน Firestore
///   users/{อีเมล}             -> uid, email, accountNumber, name, balance, createdAt
///   (อีเมล/รหัสผ่านเก็บใน Firebase Authentication ไม่ได้เก็บใน Firestore)
///   transactions/{auto id}    -> type, from, to, fromName, toName, amount,
///                                participants[], createdAt
class BankService {
  BankService._();
  static final instance = BankService._();

  static const double startingBalance = 10000;

  /// ข้อความที่ฝังใน QR code เช่น "MYBANK:1234567890"
  static const String qrPrefix = 'MYBANK:';

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _random = Random();

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(AccountModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _transactions =>
      _db.collection(TransactionModel.collectionName);

  /// บัญชีที่ login อยู่ตอนนี้ (currentUserId = ID ของ document = อีเมล)
  String? currentUserId;
  String? currentAccountNumber;

  // ---------------------------------------------------------------- QR

  static String qrDataFor(String accountNumber) => '$qrPrefix$accountNumber';

  /// แปลงข้อความที่สแกนได้จาก QR -> เลขบัญชี 10 หลัก (null ถ้าไม่ใช่ QR ของแอพเรา)
  static String? accountNumberFromQr(String raw) {
    final text = raw.trim();
    final value = text.startsWith(qrPrefix)
        ? text.substring(qrPrefix.length)
        : text;
    return RegExp(r'^\d{10}$').hasMatch(value) ? value : null;
  }

  // ---------------------------------------------------------------- Auth

  Future<String> _generateUniqueAccountNumber() async {
    while (true) {
      // หลักแรกไม่เป็น 0 เพื่อให้ได้ 10 หลักเสมอ
      final number =
          (_random.nextInt(9) + 1).toString() +
          List.generate(9, (_) => _random.nextInt(10)).join();
      if (await _userRefByAccountNumber(number) == null) return number;
    }
  }

  /// สมัครสมาชิก -> คืนค่าเลขบัญชีที่สุ่มได้
  /// อีเมล/รหัสผ่านเก็บใน Firebase Authentication ส่วนข้อมูลบัญชีเก็บใน Firestore
  Future<String> register({
    required String name,
    required String email,
    required String password,
  }) async {
    // อีเมลซ้ำ Firebase Authentication จะแจ้ง error 'email-already-in-use' ให้เอง
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
      // ใช้อีเมล (ตัวพิมพ์เล็ก) เป็น ID ของ document
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
      // บันทึกลง Firestore ไม่สำเร็จ -> ลบบัญชีใน Authentication ทิ้ง จะได้สมัครใหม่ได้
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

    // หาข้อมูลบัญชีใน Firestore จากอีเมล (ID ของ document)
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
  /// ต้องยืนยันรหัสผ่านก่อน เพราะ Firebase ไม่ให้ลบบัญชีถ้าล็อกอินไว้นานแล้ว
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw BankException('กรุณาเข้าสู่ระบบใหม่อีกครั้ง');

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } on FirebaseAuthException catch (e) {
      // ตอนลบบัญชี อีเมลถูกต้องแน่นอน (ล็อกอินอยู่แล้ว) จึงบอกแค่ว่ารหัสผ่านผิด
      if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        throw BankException('รหัสผ่านไม่ถูกต้อง');
      }
      throw BankException(_authErrorMessage(e));
    }

    // ลบข้อมูลบัญชีใน Firestore ก่อน แล้วค่อยลบบัญชีใน Authentication
    // (ประวัติใน transactions ยังเก็บไว้ เพราะอีกฝ่ายยังต้องเห็นรายการของตัวเอง)
    await _users.doc(currentUserId).delete();
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw BankException(_authErrorMessage(e));
    }
    currentUserId = null;
    currentAccountNumber = null;
  }

  /// แปลง error ของ Firebase Authentication เป็นข้อความภาษาไทย
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

  // ---------------------------------------------------------------- Read

  Stream<AccountModel> watchAccount(String userId) => _users
      .doc(userId)
      .snapshots()
      .where((doc) => doc.exists) // ข้ามตอนที่ document ถูกลบ (ลบบัญชี)
      .map((doc) => AccountModel.fromJson(doc.data()!));

  /// หา document ของ user จากเลขบัญชี (null ถ้าไม่มีบัญชีนี้)
  Future<DocumentSnapshot<Map<String, dynamic>>?> _userDocByAccountNumber(
    String accountNumber,
  ) async {
    final result = await _users
        .where('accountNumber', isEqualTo: accountNumber)
        .limit(1)
        .get();
    return result.docs.isEmpty ? null : result.docs.first;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _userRefByAccountNumber(
    String accountNumber,
  ) async => (await _userDocByAccountNumber(accountNumber))?.reference;

  /// หาเจ้าของบัญชีจากเลขบัญชี (null ถ้าไม่มีบัญชีนี้)
  Future<AccountModel?> findAccount(String accountNumber) async {
    final doc = await _userDocByAccountNumber(accountNumber);
    return doc == null ? null : AccountModel.fromJson(doc.data()!);
  }

  /// ประวัติรายการของบัญชี เรียงใหม่สุดก่อน
  /// (เรียงฝั่งแอพ จะได้ไม่ต้องสร้าง composite index ใน Firestore)
  Stream<List<TransactionModel>> watchHistory(String accountNumber) {
    return _transactions
        .where('participants', arrayContains: accountNumber)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => TransactionModel.fromJson(d.data()))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // ---------------------------------------------------------------- Money

  /// โอนเงิน ใช้ Firestore transaction เพื่อให้หักเงิน/เพิ่มเงินพร้อมกันเสมอ
  Future<void> transfer({
    required String fromAccount,
    required String toAccount,
    required double amount,
  }) async {
    if (amount <= 0) throw BankException('จำนวนเงินต้องมากกว่า 0');
    if (fromAccount == toAccount) {
      throw BankException('ไม่สามารถโอนเข้าบัญชีตัวเองได้');
    }

    // เลขบัญชีไม่เคยเปลี่ยน จึงหา document ก่อนเริ่ม transaction ได้
    final fromRef = await _userRefByAccountNumber(fromAccount);
    final toRef = await _userRefByAccountNumber(toAccount);
    if (fromRef == null) throw BankException('ไม่พบบัญชีต้นทาง');
    if (toRef == null) throw BankException('ไม่พบบัญชีปลายทาง');

    // คืนค่าข้อความ error ออกมาจาก transaction แทนการ throw ข้างใน
    final error = await _db.runTransaction<String?>((tx) async {
      final fromSnap = await tx.get(fromRef);
      final toSnap = await tx.get(toRef);
      if (!toSnap.exists) return 'ไม่พบบัญชีปลายทาง';

      final balance = (fromSnap['balance'] as num).toDouble();
      if (amount > balance) return 'เงินในบัญชีไม่เพียงพอ';

      tx.update(fromRef, {'balance': FieldValue.increment(-amount)});
      tx.update(toRef, {'balance': FieldValue.increment(amount)});
      final record = TransactionModel(
        type: 'transfer',
        from: fromAccount,
        fromName: fromSnap['name'],
        to: toAccount,
        toName: toSnap['name'],
        amount: amount,
      );
      tx.set(_transactions.doc(), record.toJson());
      return null;
    });
    if (error != null) throw BankException(error);
  }

  Future<void> withdraw({
    required String accountNumber,
    required double amount,
  }) async {
    if (amount <= 0) throw BankException('จำนวนเงินต้องมากกว่า 0');

    final ref = await _userRefByAccountNumber(accountNumber);
    if (ref == null) throw BankException('ไม่พบบัญชี');
    final error = await _db.runTransaction<String?>((tx) async {
      final snap = await tx.get(ref);
      final balance = (snap['balance'] as num).toDouble();
      if (amount > balance) return 'เงินในบัญชีไม่เพียงพอ';

      tx.update(ref, {'balance': FieldValue.increment(-amount)});
      final record = TransactionModel(
        type: 'withdraw',
        from: accountNumber,
        fromName: snap['name'],
        amount: amount,
      );
      tx.set(_transactions.doc(), record.toJson());
      return null;
    });
    if (error != null) throw BankException(error);
  }
}
