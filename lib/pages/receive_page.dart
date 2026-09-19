import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/account_model.dart';
import '../services/bank_service.dart';
import '../widgets/common.dart';

/// หน้ารับเงิน: โชว์ QR code และเลขบัญชีของเรา ให้คนอื่นเอาไปโอน
class ReceivePage extends StatelessWidget {
  final AccountModel account;
  const ReceivePage({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รับเงิน')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Text(
                'QR code รับเงิน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              QrImageView(
                data: BankService.qrDataFor(account.accountNumber),
                size: 260,
              ),
              const SizedBox(height: 32),
              const Text(
                'ชื่อบัญชี',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              Text(
                account.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'เลขบัญชี',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              Text(
                formatAccountNumber(account.accountNumber),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, color: brandColor),
                label: const Text('คัดลอกเลขบัญชี'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: account.accountNumber));
                  showMessage(context, 'คัดลอกเลขบัญชีแล้ว');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
