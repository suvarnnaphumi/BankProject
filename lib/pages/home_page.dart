import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/bank_service.dart';
import '../widgets/common.dart';
import 'exchange_rate_page.dart';
import 'receive_page.dart';
import 'settings_page.dart';
import 'team_page.dart';
import 'transfer_page.dart';
import 'withdraw_page.dart';

/// หน้าหลักหลังล็อกอินเสร็จ: แสดงยอดเงินคงเหลือ, ปุ่มเมนู, และรายการธุรกรรมล่าสุด
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final myAccount = BankService.instance.currentAccountNumber!;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('My Bank'),
        leading: IconButton(
          tooltip: 'สมาชิกในกลุ่ม',
          icon: const Icon(Icons.groups),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeamPage()),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'ตั้งค่า',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<Account>(
        stream: BankService.instance.watchAccount(
          BankService.instance.currentUserId!,
        ),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(errorMessage(snap.error!)));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final account = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BalanceCard(account: account),
              const SizedBox(height: 16),
              Row(
                children: [
                  _MenuButton(
                    icon: Icons.send,
                    label: 'โอนเงิน',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransferPage()),
                    ),
                  ),
                  _MenuButton(
                    icon: Icons.atm,
                    label: 'ถอนเงิน',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WithdrawPage()),
                    ),
                  ),
                  _MenuButton(
                    icon: Icons.qr_code,
                    label: 'รับเงิน',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReceivePage(account: account),
                      ),
                    ),
                  ),
                  _MenuButton(
                    icon: Icons.currency_exchange,
                    label: 'ค่าเงิน',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ExchangeRatePage(balance: account.balance),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'รายการล่าสุด',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _History(accountNumber: myAccount),
            ],
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Account account;
  const _BalanceCard({required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brandColor, Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.name,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            formatAccountNumber(account.accountNumber),
            style: const TextStyle(color: Colors.white70, letterSpacing: 1),
          ),
          const SizedBox(height: 20),
          const Text('ยอดเงินคงเหลือ', style: TextStyle(color: Colors.white70)),
          Text(
            formatMoney(account.balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Icon(icon, size: 32, color: brandColor),
                const SizedBox(height: 6),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  final String accountNumber;
  const _History({required this.accountNumber});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return StreamBuilder<List<BankTransaction>>(
      stream: BankService.instance.watchHistory(accountNumber),
      builder: (context, snap) {
        if (snap.hasError) return Text(errorMessage(snap.error!));
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'ยังไม่มีรายการ',
                style: TextStyle(color: Colors.black45),
              ),
            ),
          );
        }

        return Column(
          children: items.map((t) {
            final String title;
            final IconData icon;
            final bool incoming;
            if (t.type == 'withdraw') {
              title = 'ถอนเงิน';
              icon = Icons.atm;
              incoming = false;
            } else if (t.to == accountNumber) {
              title = 'รับเงินจาก ${t.fromName}';
              icon = Icons.call_received;
              incoming = true;
            } else {
              title = 'โอนให้ ${t.toName}';
              icon = Icons.call_made;
              incoming = false;
            }
            final color = incoming ? Colors.green : Colors.red;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icon, color: color),
                ),
                title: Text(title),
                subtitle: Text(dateFormat.format(t.createdAt)),
                trailing: Text(
                  '${incoming ? '+' : '-'}${formatMoney(t.amount)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
