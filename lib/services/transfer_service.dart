import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction_model.dart';
import 'account_service.dart';
import 'bank_exception.dart';

/// โอนเงินจากบัญชีหนึ่งไปอีกบัญชีหนึ่ง
class TransferService {
  TransferService._();
  static final instance = TransferService._();

  final _db = FirebaseFirestore.instance;

  /// โอนเงินใช้ Firestore transaction
  Future<void> transfer({
    required String fromAccount,
    required String toAccount,
    required double amount,
  }) async {
    if (amount <= 0) throw BankException('จำนวนเงินต้องมากกว่า 0');
    if (fromAccount == toAccount) {
      throw BankException('ไม่สามารถโอนเข้าบัญชีตัวเองได้');
    }

    final fromRef = await AccountService.instance.refByAccountNumber(
      fromAccount,
    );
    final toRef = await AccountService.instance.refByAccountNumber(toAccount);
    if (fromRef == null) throw BankException('ไม่พบบัญชีต้นทาง');
    if (toRef == null) throw BankException('ไม่พบบัญชีปลายทาง');

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
      tx.set(
        _db.collection(TransactionModel.collectionName).doc(),
        record.toJson(),
      );
      return null;
    });
    if (error != null) throw BankException(error);
  }
}
