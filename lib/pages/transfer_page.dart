import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/transfer_service.dart';
import '../widgets/common.dart';
import 'scan_page.dart';

/// โอนเงิน: กรอกเลขบัญชีเอง หรือกดไอคอนสแกน QR (ซึ่งจะเติมเลขบัญชีให้อัตโนมัติ)
class TransferPage extends StatefulWidget {
  /// เลขบัญชีปลายทางที่ได้จากการสแกน QR (ถ้ามี จะใส่ไว้ในช่องให้เลย)
  final String? initialAccountNumber;
  const TransferPage({super.key, this.initialAccountNumber});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumber = TextEditingController();
  final _amount = TextEditingController();

  AccountModel? _receiver; // เจ้าของบัญชีปลายทางที่ค้นเจอ
  bool _searching = false;
  bool _sending = false;

  String get _myAccount => AuthService.instance.currentAccountNumber!;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAccountNumber;
    if (initial != null) {
      _accountNumber.text = initial;
      // รอให้หน้าวาดเสร็จก่อน แล้วค่อยค้นชื่อเจ้าของบัญชี
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _lookupReceiver(initial),
      );
    }
  }

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
      final account = await AccountService.instance.findAccount(number);
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

    final ok = await showConfirmDialog(
      context,
      title: 'ยืนยันการโอนเงิน',
      confirmLabel: 'ยืนยัน',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ไปยัง: ${receiver.name}', style: const TextStyle(fontSize: 16)),
          Text(
            'เลขบัญชี: ${formatAccountNumber(receiver.accountNumber)}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            'จำนวน: ${formatMoney(amount)}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    if (!ok || !mounted) return;

    setState(() => _sending = true);
    try {
      await TransferService.instance.transfer(
        fromAccount: _myAccount,
        toAccount: receiver.accountNumber,
        amount: amount,
      );
      if (!mounted) return;
      await showResultDialog(
        context,
        success: true,
        title: 'โอนเงินสำเร็จ',
        message: 'จำนวน ${formatMoney(amount)}\nให้ ${receiver.name}',
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
    final userId = AuthService.instance.currentUserId!;

    return Scaffold(
      appBar: AppBar(title: const Text('โอนเงิน')),
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
              const SizedBox(height: 24),
              const SectionLabel('ไปยัง'),
              TextFormField(
                controller: _accountNumber,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: InputDecoration(
                  hintText: 'เลขบัญชีปลายทาง (10 หลัก)',
                  prefixIcon: const Icon(Icons.account_balance),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'สแกน QR Code',
                          icon: const Icon(
                            Icons.qr_code_scanner,
                            color: brandColor,
                          ),
                          onPressed: _scanQr,
                        ),
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
              if (_receiver != null) ...[
                const SizedBox(height: 4),
                _ReceiverBox(account: _receiver!),
              ],
              const SizedBox(height: 16),
              AmountField(controller: _amount),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _sending ? null : _confirmAndSend,
                child: _sending ? const ButtonLoading() : const Text('ถัดไป'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// กล่องสีเทาแสดงชื่อ + เลขบัญชีของผู้รับ
class _ReceiverBox extends StatelessWidget {
  final AccountModel account;
  const _ReceiverBox({required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: greyBoxColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // รูปโปรไฟล์ของผู้รับ (ถ้ายังไม่ได้ตั้งรูป จะเป็นไอคอนคน)
          ProfileAvatar(photo: account.photo, size: 48),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  formatAccountNumber(account.accountNumber),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
