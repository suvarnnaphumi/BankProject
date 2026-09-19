import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../services/bank_service.dart';
import '../widgets/common.dart';
import 'login_page.dart';

/// แท็บตั้งค่า: ดูข้อมูลบัญชี และลบบัญชีผู้ใช้
/// (ปุ่มออกจากระบบอยู่มุมขวาบนของหน้าหลัก)
class SettingsPage extends StatelessWidget {
  final AccountModel account;
  const SettingsPage({super.key, required this.account});

  Future<void> _deleteAccount(BuildContext context) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted != true || !context.mounted) return;

    // เก็บ messenger ไว้ก่อน เพราะหน้านี้จะถูกปิดไปตอนกลับหน้า login
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'ลบบัญชีเรียบร้อยแล้ว',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: brandColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        // ข้อมูลบัญชี
        ShadowCard(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(account.email, style: const TextStyle(fontSize: 16)),
              Text(
                'เลขบัญชี ${formatAccountNumber(account.accountNumber)}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 220,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: dangerColor),
              onPressed: () => _deleteAccount(context),
              child: const Text('ลบบัญชี'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Popup ยืนยันการลบบัญชี ต้องกรอกรหัสผ่านก่อน (คืนค่า true ถ้าลบสำเร็จ)
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'กรุณากรอกรหัสผ่าน');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BankService.instance.deleteAccount(_password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: dangerColor,
        size: 96,
      ),
      title: const Text(
        'ลบบัญชี',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'บัญชีและยอดเงินจะถูกลบทั้งหมด\nไม่สามารถกู้คืนได้',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          const Text(
            'กรอกรหัสผ่านเพื่อยืนยัน',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: 'รหัสผ่าน',
              prefixIcon: const Icon(Icons.lock),
              errorText: _error,
            ),
            onSubmitted: (_) => _delete(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: dangerColor),
          onPressed: _loading ? null : _delete,
          child: _loading ? const ButtonLoading() : const Text('ลบบัญชี'),
        ),
      ],
    );
  }
}
