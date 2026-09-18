import 'package:flutter/material.dart';

import '../services/bank_service.dart';
import '../widgets/common.dart';

/// หน้าถอนเงิน: กรอกจำนวนเงินที่ต้องการถอน แล้วกดถอน (จะตัดเงินออกจากบัญชีของเรา)
class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amount.text.trim());
    setState(() => _loading = true);
    try {
      await BankService.instance.withdraw(
        accountNumber: BankService.instance.currentAccountNumber!,
        amount: amount,
      );
      if (!mounted) return;
      await showResultDialog(
        context,
        success: true,
        title: 'ถอนเงินสำเร็จ',
        message: 'ถอนเงินจำนวน ${formatMoney(amount)}',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      // กรณีถอนเกินยอดคงเหลือ จะได้ข้อความ "เงินในบัญชีไม่เพียงพอ"
      await showResultDialog(
        context,
        success: false,
        title: 'ถอนเงินไม่สำเร็จ',
        message: errorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ถอนเงิน')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StreamBuilder<Account>(
                stream: BankService.instance.watchAccount(
                  BankService.instance.currentUserId!,
                ),
                builder: (context, snap) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet,
                      color: brandColor,
                    ),
                    title: const Text('ยอดเงินคงเหลือ'),
                    trailing: Text(
                      snap.hasData ? formatMoney(snap.data!.balance) : '...',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AmountField(controller: _amount),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loading ? null : _withdraw,
                icon: const Icon(Icons.atm),
                label: const Text('ถอนเงิน'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
