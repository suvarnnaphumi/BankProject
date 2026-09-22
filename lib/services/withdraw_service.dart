import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction_model.dart';
import 'account_service.dart';
import 'bank_exception.dart';

/// ถอนเงินออกจากบัญชี
class WithdrawService {
  WithdrawService._();
  static final instance = WithdrawService._();

  final _db = FirebaseFirestore.instance;

  Future<void> withdraw({
    required String accountNumber,
    required double amount,
  }) async {
    if (amount <= 0) throw BankException('จำนวนเงินต้องมากกว่า 0');

    final ref = await AccountService.instance.refByAccountNumber(accountNumber);
    if (ref == null) throw BankException('ไม่พบบัญชี');

    // เช็คยอดเงิน + หักเงิน + บันทึกประวัติ ใน transaction เดียวกัน
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
      tx.set(
        _db.collection(TransactionModel.collectionName).doc(),
        record.toJson(),
      );
      return null;
    });
    if (error != null) throw BankException(error);
  }
}
