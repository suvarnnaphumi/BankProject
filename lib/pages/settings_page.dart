import 'package:flutter/material.dart';

import '../services/bank_service.dart';
import '../widgets/common.dart';
import 'login_page.dart';

/// หน้าตั้งค่า: ดูข้อมูลบัญชี, ออกจากระบบ, ลบบัญชีผู้ใช้
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _goToLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบใช่ไหม?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await BankService.instance.logout();
    if (context.mounted) _goToLogin(context);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted != true || !context.mounted) return;

    // เก็บ messenger ไว้ก่อน เพราะหน้านี้จะถูกปิดไปตอนกลับหน้า login
    final messenger = ScaffoldMessenger.of(context);
    _goToLogin(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('ลบบัญชีเรียบร้อยแล้ว'),
        backgroundColor: brandColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = BankService.instance.currentUserId;
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: userId == null
          ? const SizedBox()
          : StreamBuilder<Account>(
              stream: BankService.instance.watchAccount(userId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildBody(context, snap.data!);
              },
            ),
    );
  }

  Widget _buildBody(BuildContext context, Account account) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ข้อมูลบัญชี
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.person, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(account.email),
                      Text(
                        'เลขบัญชี ${formatAccountNumber(account.accountNumber)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: brandColor),
                title: const Text('ออกจากระบบ'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _logout(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'ลบบัญชีผู้ใช้',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text('ลบบัญชีและยอดเงินทั้งหมดอย่างถาวร'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _deleteAccount(context),
              ),
            ],
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
      icon: const Icon(Icons.warning_amber, color: Colors.red, size: 48),
      title: const Text('ลบบัญชีผู้ใช้'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'บัญชีและยอดเงินทั้งหมดจะถูกลบถาวร และกู้คืนไม่ได้\n'
            'กรอกรหัสผ่านเพื่อยืนยัน',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            enabled: !_loading,
            decoration: InputDecoration(
              labelText: 'รหัสผ่าน',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
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
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _loading ? null : _delete,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('ลบบัญชี'),
        ),
      ],
    );
  }
}
