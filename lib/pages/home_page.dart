import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/transaction_service.dart';
import '../widgets/common.dart';
import 'login_page.dart';
import 'menu_page.dart';
import 'settings_page.dart';
import 'team_page.dart';

/// หน้าหลักหลังล็อกอิน: แสดงยอดเงิน + รายการย้อนหลัง + แถบเมนูด้านล่าง 4 แท็บ
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

    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.instance.currentUserId;

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
          : StreamBuilder<AccountModel>(
              stream: AccountService.instance.watchAccount(userId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(errorMessage(snap.error!)));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final account = snap.data!;

                return IndexedStack(
                  index: _tab,
                  children: [
                    _HomeTab(account: account),
                    MenuPage(account: account),
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

/// แถบเมนูล่าง

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

/// เนื้อหาแท็บหน้าหลัก
class _HomeTab extends StatelessWidget {
  final AccountModel account;
  const _HomeTab({required this.account});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        BalanceCard(account: account, showPhoto: true),
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

    return StreamBuilder<List<TransactionModel>>(
      stream: TransactionService.instance.watchHistory(accountNumber),
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
              icon = const Icon(Icons.credit_card, color: brandColor, size: 40);
              incoming = false;
            } else if (t.type == 'savings_deposit') {
              // ย้ายเงินไปบัญชีออม = เงินออกจากยอดหลัก
              title = 'ฝากเงินออม';
              icon = const Icon(Icons.savings, color: brandColor, size: 40);
              incoming = false;
            } else if (t.type == 'savings_withdraw') {
              // ย้ายเงินออมกลับมา = เงินเข้ายอดหลัก
              title = 'ถอนเงินออม';
              icon = const Icon(Icons.savings, color: brandColor, size: 40);
              incoming = true;
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
