import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'home_page.dart';
import 'register_page.dart';

/// หน้าล็อกอินเพื่อเข้าสู่ระบบ: กรอกอีเมลและรหัสผ่าน หรือกดสมัครสมาชิก
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 50),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'My Bank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w700,
                      color: brandColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'เข้าสู่ระบบ',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'อีเมล',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'กรุณากรอกอีเมล' : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'รหัสผ่าน',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'กรุณากรอกรหัสผ่าน' : null,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const ButtonLoading()
                        : const Text('เข้าสู่ระบบ'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ยังไม่มีบัญชี?  ',
                        style: TextStyle(fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        ),
                        child: const Text(
                          'สมัครสมาชิก',
                          style: TextStyle(
                            fontSize: 16,
                            color: linkColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
