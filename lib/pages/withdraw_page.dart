import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/withdraw_service.dart';
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
      await WithdrawService.instance.withdraw(
        accountNumber: AuthService.instance.currentAccountNumber!,
        amount: amount,
      );
      if (!mounted) return;
      await showResultDialog(
        context,
        success: true,
        title: 'ถอนเงินสำเร็จ',
        message: 'จำนวน ${formatMoney(amount)}',
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
    final userId = AuthService.instance.currentUserId!;

    return Scaffold(
      appBar: AppBar(title: const Text('ถอนเงิน')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionLabel('จาก'),
              StreamBuilder<AccountModel>(
                stream: AccountService.instance.watchAccount(userId),
                builder: (context, snap) => snap.hasData
                    ? BalanceCard(account: snap.data!)
                    : const SizedBox(height: 160),
              ),
              const SizedBox(height: 32),
              AmountField(controller: _amount),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _loading ? null : _withdraw,
                child: _loading ? const ButtonLoading() : const Text('ถัดไป'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
