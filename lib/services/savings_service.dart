import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction_model.dart';
import 'account_service.dart';
import 'bank_exception.dart';

/// บัญชีออม: ย้ายเงินไป-กลับระหว่างยอดเงินหลัก (balance) กับเงินออม (savingsBalance)
class SavingsService {
  SavingsService._();
  static final instance = SavingsService._();

  final _db = FirebaseFirestore.instance;

  /// ย้ายเงินจากยอดเงินหลัก -> บัญชีออม
  Future<void> deposit({
    required String accountNumber,
    required double amount,
  }) => _move(accountNumber, amount, toSavings: true);

  /// ย้ายเงินจากบัญชีออม -> ยอดเงินหลัก
  Future<void> withdraw({
    required String accountNumber,
    required double amount,
  }) => _move(accountNumber, amount, toSavings: false);

  /// ย้ายเงินระหว่าง balance กับ savingsBalance ใน document เดียวกัน
  /// ใช้ transaction เหมือนการโอน เงินจะได้ไม่หายถ้าเน็ตหลุดกลางคัน
  Future<void> _move(
    String accountNumber,
    double amount, {
    required bool toSavings,
  }) async {
    if (amount <= 0) throw BankException('จำนวนเงินต้องมากกว่า 0');

    final ref = await AccountService.instance.refByAccountNumber(accountNumber);
    if (ref == null) throw BankException('ไม่พบบัญชี');
    final error = await _db.runTransaction<String?>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data()!;
      final balance = (data['balance'] as num).toDouble();
      // บัญชีเก่าอาจยังไม่มีช่อง savingsBalance -> ถือว่าเป็น 0
      final savings = (data['savingsBalance'] as num? ?? 0).toDouble();

      if (toSavings && amount > balance) return 'เงินในบัญชีไม่เพียงพอ';
      if (!toSavings && amount > savings) return 'เงินออมไม่เพียงพอ';

      final change = toSavings ? amount : -amount;
      tx.update(ref, {
        'balance': FieldValue.increment(-change),
        'savingsBalance': FieldValue.increment(change),
      });
      final record = TransactionModel(
        type: toSavings ? 'savings_deposit' : 'savings_withdraw',
        from: accountNumber,
        fromName: data['name'],
        amount: amount,
      );
      tx.set(
        _db.collection(TransactionModel.collectionName).doc(),
        record.toJson(),
      );
      return null;
    });
    if (error != null) throw BankException(error);
  }
}
