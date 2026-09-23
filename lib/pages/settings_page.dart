import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/account_model.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Row(
            children: [
              _ProfilePhotoPicker(photo: account.photo),
              const SizedBox(width: 20),
              Expanded(
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

/// รูปโปรไฟล์ที่กดได้: กดแล้วเลือกรูปใหม่จากเครื่อง หรือลบรูปออก
class _ProfilePhotoPicker extends StatefulWidget {
  final Uint8List? photo;
  const _ProfilePhotoPicker({required this.photo});

  @override
  State<_ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends State<_ProfilePhotoPicker> {
  bool _uploading = false;

  Future<void> _showOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกรูปจากเครื่อง'),
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            if (widget.photo != null)
              ListTile(
                leading: const Icon(Icons.delete, color: dangerColor),
                title: const Text(
                  'ลบรูปโปรไฟล์',
                  style: TextStyle(color: dangerColor),
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == 'pick') await _pickPhoto();
    if (action == 'remove') {
      await _run(AccountService.instance.removeProfilePhoto);
    }
  }

  Future<void> _pickPhoto() async {
    // ย่อรูปตั้งแต่ตอนเลือก เหลือไม่เกิน 256x256
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 70,
    );
    if (file == null) return; // ผู้ใช้กดยกเลิก
    final bytes = await file.readAsBytes();
    await _run(() => AccountService.instance.updateProfilePhoto(bytes));
  }

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _uploading = true);
    try {
      await task();
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _uploading ? null : _showOptions,
      child: Stack(
        children: [
          ProfileAvatar(photo: widget.photo, size: 72),
          if (_uploading)
            const Positioned.fill(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          // ไอคอนกล้องเล็กๆ มุมขวาล่าง บอกว่ากดเปลี่ยนรูปได้
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Popup ยืนยันการลบบัญชี ต้องกรอกรหัสผ่านก่อน
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
      await AuthService.instance.deleteAccount(_password.text);
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

      content: SingleChildScrollView(
        child: Column(
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
