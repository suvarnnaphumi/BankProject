import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/bank_service.dart';
import '../widgets/common.dart';
import 'exchange_rate_page.dart';
import 'login_page.dart';
import 'receive_page.dart';
import 'scan_page.dart';
import 'settings_page.dart';
import 'team_page.dart';
import 'transfer_page.dart';
import 'withdraw_page.dart';

/// หน้าหลักหลังล็อกอิน: มีแถบเมนูด้านล่าง 4 แท็บ
/// หน้าหลัก (ยอดเงิน + รายการย้อนหลัง) / ธุรกรรม (ปุ่มเมนู) / ตั้งค่า / สมาชิก
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  Future<void> _logout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'ออกจากระบบ',
      content: const Text(
        'ต้องการออกจากระบบใช่ไหม ?',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16),
      ),
      confirmLabel: 'ออกจากระบบ',
      danger: true,
    );
    if (!ok) return;

    await BankService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = BankService.instance.currentUserId;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Bank',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: brandColor,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: userId == null
          ? const SizedBox()
          : StreamBuilder<Account>(
              stream: BankService.instance.watchAccount(userId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(errorMessage(snap.error!)));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final account = snap.data!;
                // IndexedStack เก็บทุกแท็บไว้ สลับแท็บแล้วไม่ต้องโหลดใหม่
                return IndexedStack(
                  index: _tab,
                  children: [
                    _HomeTab(account: account),
                    _MenuTab(account: account),
                    SettingsPage(account: account),
                    const TeamPage(),
                  ],
                );
              },
            ),
      bottomNavigationBar: _BottomBar(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ---------------------------------------------------------------- แถบเมนูล่าง

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomBar({required this.index, required this.onChanged});

  static const _items = [
    (Icons.home, 'หน้าหลัก'),
    (Icons.account_balance_wallet, 'ธุรกรรม'),
    (Icons.settings, 'ตั้งค่า'),
    (Icons.people, 'สมาชิก'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: brandColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _items[i].$1,
                          size: 30,
                          // แท็บที่เลือกอยู่เป็นสีดำ ที่เหลือเป็นสีขาว
                          color: i == index ? Colors.black : Colors.white,
                        ),
                        Text(
                          _items[i].$2,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: i == index ? Colors.black : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- แท็บหน้าหลัก

class _HomeTab extends StatelessWidget {
  final Account account;
  const _HomeTab({required this.account});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        BalanceCard(account: account),
        const SizedBox(height: 16),
        const SectionLabel('รายการย้อนหลัง'),
        _History(accountNumber: account.accountNumber),
      ],
    );
  }
}

class _History extends StatelessWidget {
  final String accountNumber;
  const _History({required this.accountNumber});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH.mm');

    return StreamBuilder<List<BankTransaction>>(
      stream: BankService.instance.watchHistory(accountNumber),
      builder: (context, snap) {
        if (snap.hasError) return Text(errorMessage(snap.error!));
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 120),
            child: Center(
              child: Text(
                'ไม่มีรายการย้อนหลัง',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          );
        }

        return Column(
          children: items.map((t) {
            final String title;
            final Widget icon;
            final bool incoming;
            if (t.type == 'withdraw') {
              title = 'ถอนเงิน';
              icon = const Icon(Icons.credit_card, size: 40);
              incoming = false;
            } else if (t.to == accountNumber) {
              title = 'รับเงินจาก ${t.fromName}';
              icon = const Icon(Icons.south_west, color: incomeColor, size: 36);
              incoming = true;
            } else {
              title = 'โอนเงิน ให้ ${t.toName}';
              icon = const Icon(Icons.north_east, color: dangerColor, size: 36);
              incoming = false;
            }

            return ShadowCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Row(
                children: [
                  SizedBox(width: 48, child: Center(child: icon)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          dateFormat.format(t.createdAt),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${incoming ? '+' : '-'}${formatMoney(t.amount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: incoming ? incomeColor : dangerColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- แท็บธุรกรรม (ปุ่มเมนู)

class _MenuTab extends StatelessWidget {
  final Account account;
  const _MenuTab({required this.account});

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
      (Icons.qr_code_scanner, 'สแกน', () => _scanAndTransfer(context)),
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
