import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction_model.dart';

/// อ่านรายการธุรกรรม: ประวัติรายการ และยอดเงินเข้าทั้งปี
class TransactionService {
  TransactionService._();
  static final instance = TransactionService._();

  CollectionReference<Map<String, dynamic>> get _transactions =>
      FirebaseFirestore.instance.collection(TransactionModel.collectionName);

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

  Future<double> incomeThisYear(String accountNumber) async {
    final year = DateTime.now().year;
    final snap = await _transactions
        .where('participants', arrayContains: accountNumber)
        .get();
    var total = 0.0;
    for (final doc in snap.docs) {
      final t = TransactionModel.fromJson(doc.data());
      if (t.type == 'transfer' &&
          t.to == accountNumber &&
          t.createdAt.year == year) {
        total += t.amount;
      }
    }
    return total;
  }
}
