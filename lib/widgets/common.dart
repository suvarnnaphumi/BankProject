import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/bank_service.dart';

const brandColor = Color(0xFF1B5E20);

final _money = NumberFormat('#,##0.00');

String formatMoney(double amount) => '${_money.format(amount)} ฿';

/// 1234567890 -> 123-4-56789-0 (รูปแบบเลขบัญชีแบบธนาคารไทย)
String formatAccountNumber(String n) {
  if (n.length != 10) return n;
  return '${n.substring(0, 3)}-${n.substring(3, 4)}-'
      '${n.substring(4, 9)}-${n.substring(9)}';
}

String errorMessage(Object e) =>
    e is BankException ? e.message : 'เกิดข้อผิดพลาด: $e';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : brandColor,
      ),
    );
}

/// Popup แจ้งผลสำเร็จ / ไม่สำเร็จ
Future<void> showResultDialog(
  BuildContext context, {
  required bool success,
  required String title,
  required String message,
}) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      icon: Icon(
        success ? Icons.check_circle : Icons.error,
        color: success ? Colors.green : Colors.red,
        size: 56,
      ),
      title: Text(title),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ตกลง'),
        ),
      ],
    ),
  );
}

/// ช่องกรอกจำนวนเงิน ใช้ร่วมกันในหน้าโอน/ถอน
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  const AmountField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'จำนวนเงิน (บาท)',
        prefixIcon: Icon(Icons.payments_outlined),
        border: OutlineInputBorder(),
      ),
      validator: (v) {
        final amount = double.tryParse(v?.trim() ?? '');
        if (amount == null) return 'กรุณากรอกจำนวนเงิน';
        if (amount <= 0) return 'จำนวนเงินต้องมากกว่า 0';
        return null;
      },
    );
  }
}
