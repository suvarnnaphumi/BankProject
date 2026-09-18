import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/bank_service.dart';
import '../widgets/common.dart';

/// หน้ารับเงิน: โชว์ QR code หรือเลขบัญชีของเรา ให้คนอื่นเอาไปโอน
class ReceivePage extends StatelessWidget {
  final Account account;
  const ReceivePage({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('รับเงิน'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.qr_code), text: 'QR Code'),
              Tab(icon: Icon(Icons.numbers), text: 'เลขบัญชี'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _QrTab(account: account),
            _AccountNumberTab(account: account),
          ],
        ),
      ),
    );
  }
}

class _QrTab extends StatelessWidget {
  final Account account;
  const _QrTab({required this.account});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'ให้ผู้โอนสแกน QR code นี้',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 12),
                ],
              ),
              child: QrImageView(
                data: BankService.qrDataFor(account.accountNumber),
                size: 240,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              account.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              formatAccountNumber(account.accountNumber),
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountNumberTab extends StatelessWidget {
  final Account account;
  const _AccountNumberTab({required this.account});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance, size: 48, color: brandColor),
                const SizedBox(height: 12),
                const Text(
                  'ชื่อบัญชี',
                  style: TextStyle(color: Colors.black54),
                ),
                Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'เลขที่บัญชี',
                  style: TextStyle(color: Colors.black54),
                ),
                Text(
                  formatAccountNumber(account.accountNumber),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('คัดลอกเลขบัญชี'),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: account.accountNumber),
                    );
                    showMessage(context, 'คัดลอกเลขบัญชีแล้ว');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
