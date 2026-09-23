import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../widgets/common.dart';
import 'exchange_rate_page.dart';
import 'receive_page.dart';
import 'savings_page.dart';
import 'scan_page.dart';
import 'tax_page.dart';
import 'transfer_page.dart';
import 'withdraw_page.dart';

/// หน้าธุรกรรม: ปุ่มเมนู 7 ปุ่ม โอนเงิน, สแกน, รับเงิน, ถอนเงิน, เงินออม, ภาษี, ค่าเงิน
class MenuPage extends StatelessWidget {
  final AccountModel account;
  const MenuPage({super.key, required this.account});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  /// สแกน QR แล้วเปิดหน้าโอนเงิน พร้อมใส่เลขบัญชีที่สแกนได้ให้เลย
  Future<void> _scanAndTransfer(BuildContext context) async {
    final accountNumber = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (accountNumber == null || !context.mounted) return;
    _open(context, TransferPage(initialAccountNumber: accountNumber));
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.account_balance,
        'โอนเงิน',
        () => _open(context, const TransferPage()),
      ),
      (
        Icons.qr_code_scanner,
        'สแกน',
        () => _scanAndTransfer(context)),
      (
        Icons.qr_code_2,
        'รับเงิน',
        () => _open(context, ReceivePage(account: account)),
      ),
      (
        Icons.credit_card,
        'ถอนเงิน',
        () => _open(context, const WithdrawPage()),
      ),
      (
        Icons.savings,
        'ออมเงิน',
        () => _open(context, SavingsPage(account: account)),
      ),
      (
        Icons.receipt_long,
        'คิดภาษี',
        () => _open(context, const TaxPage())),
      (
        Icons.swap_horiz,
        'ค่าเงิน',
        () => _open(context, ExchangeRatePage(balance: account.balance)),
      ),
    ];

    return GridView.count(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      crossAxisCount: 3,
      mainAxisSpacing: 24,
      crossAxisSpacing: 24,
      children: [
        for (final (icon, label, onTap) in items)
          ShadowCard(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: brandColor),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
