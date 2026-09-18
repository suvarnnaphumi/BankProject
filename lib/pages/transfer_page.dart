import 'package:flutter/material.dart';

import '../services/bank_service.dart';
import '../widgets/common.dart';
import 'scan_page.dart';

/// โอนเงิน: กรอกเลขบัญชีเอง หรือเลือกแทบสแกน QR (ซึ่งจะเติมเลขบัญชีให้อัตโนมัติ)
class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumber = TextEditingController();
  final _amount = TextEditingController();

  Account? _receiver; // เจ้าของบัญชีปลายทางที่ค้นเจอ
  bool _searching = false;
  bool _sending = false;

  String get _myAccount => BankService.instance.currentAccountNumber!;

  @override
  void dispose() {
    _accountNumber.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// เมื่อกรอกครบ 10 หลัก ให้ค้นชื่อเจ้าของบัญชีมาโชว์
  Future<void> _lookupReceiver(String number) async {
    setState(() => _receiver = null);
    if (number.length != 10) return;
    setState(() => _searching = true);
    try {
      final account = await BankService.instance.findAccount(number);
      if (!mounted || _accountNumber.text != number) return;
      setState(() => _receiver = account);
      if (account == null) {
        showMessage(context, 'ไม่พบบัญชีนี้', error: true);
      }
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _scanQr() async {
    final accountNumber = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (accountNumber == null || !mounted) return;
    _accountNumber.text = accountNumber;
    await _lookupReceiver(accountNumber);
  }

  Future<void> _confirmAndSend() async {
    if (!_formKey.currentState!.validate()) return;
    final receiver = _receiver;
    if (receiver == null) {
      showMessage(context, 'กรุณาระบุบัญชีปลายทางให้ถูกต้อง', error: true);
      return;
    }
    final amount = double.parse(_amount.text.trim());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการโอนเงิน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ไปยัง: ${receiver.name}'),
            Text('เลขบัญชี: ${formatAccountNumber(receiver.accountNumber)}'),
            const SizedBox(height: 8),
            Text(
              'จำนวน: ${formatMoney(amount)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    try {
      await BankService.instance.transfer(
        fromAccount: _myAccount,
        toAccount: receiver.accountNumber,
        amount: amount,
      );
      if (!mounted) return;
      await showResultDialog(
        context,
        success: true,
        title: 'โอนเงินสำเร็จ',
        message: 'โอน ${formatMoney(amount)}\nให้ ${receiver.name}',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      await showResultDialog(
        context,
        success: false,
        title: 'โอนเงินไม่สำเร็จ',
        message: errorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('โอนเงิน')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _scanQr,
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text('สแกน QR Code'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('หรือกรอกเลขบัญชี'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              TextFormField(
                controller: _accountNumber,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: 'เลขบัญชีปลายทาง (10 หลัก)',
                  prefixIcon: const Icon(Icons.account_balance),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _lookupReceiver,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (!RegExp(r'^\d{10}$').hasMatch(t)) {
                    return 'เลขบัญชีต้องเป็นตัวเลข 10 หลัก';
                  }
                  if (t == _myAccount) return 'ไม่สามารถโอนเข้าบัญชีตัวเองได้';
                  return null;
                },
              ),
              if (_receiver != null)
                Card(
                  color: Colors.green.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.person, color: brandColor),
                    title: Text(_receiver!.name),
                    subtitle: Text(
                      formatAccountNumber(_receiver!.accountNumber),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              AmountField(controller: _amount),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _sending ? null : _confirmAndSend,
                icon: const Icon(Icons.send),
                label: const Text('โอนเงิน'),
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
