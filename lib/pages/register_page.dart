import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/bank_service.dart';
import '../widgets/common.dart';
import 'home_page.dart';

/// หน้าสมัครสมาชิก: กรอกชื่อ-นามสกุล, อีเมล, รหัสผ่าน แล้วสร้างบัญชีใหม่
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final accountNumber = await BankService.instance.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      await _showNewAccount(accountNumber);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// โชว์เลขบัญชี + QR ที่สุ่มได้ตอนสมัคร
  Future<void> _showNewAccount(String accountNumber) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          'สมัครสมาชิกสำเร็จ!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('เลขบัญชีของคุณคือ', style: TextStyle(fontSize: 16)),
            Text(
              formatAccountNumber(accountNumber),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(data: BankService.qrDataFor(accountNumber)),
            ),
            Text(
              'ได้รับเงินเริ่มต้น ${formatMoney(BankService.startingBalance)}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('เริ่มใช้งาน'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  hintText: 'ชื่อ-นามสกุล',
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'กรุณากรอกชื่อ-นามสกุล' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'อีเมล',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'กรุณากรอกอีเมล';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                    return 'รูปแบบอีเมลไม่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'รหัสผ่าน (อย่างน้อย 6 ตัว)',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (v) => (v ?? '').length < 6
                    ? 'รหัสผ่านต้องมีอย่างน้อย 6 ตัว'
                    : null,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const ButtonLoading()
                    : const Text('สร้างบัญชี'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
