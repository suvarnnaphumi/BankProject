import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/savings_service.dart';
import '../services/transaction_service.dart';
import '../widgets/common.dart';

/// หน้าบัญชีออม: ยอดเงินออม + ฝาก/ถอนเงินออมเอง + ประวัติ
class SavingsPage extends StatelessWidget {
  final AccountModel account;
  const SavingsPage({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.instance.currentUserId!;

    return Scaffold(
      appBar: AppBar(title: const Text('บัญชีออม')),
      body: StreamBuilder<AccountModel>(
        stream: AccountService.instance.watchAccount(userId),
        builder: (context, snap) {
          final current = snap.data ?? account;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              _SavingsBalanceCard(account: current),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('ฝากเงินออม'),
                      onPressed: () => _openMoveDialog(
                        context,
                        toSavings: true,
                        maxAmount: current.balance,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.remove),
                      label: const Text('ถอนเงินออม'),
                      onPressed: () => _openMoveDialog(
                        context,
                        toSavings: false,
                        maxAmount: current.savingsBalance,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionLabel('ประวัติเงินออม'),
              _SavingsHistory(accountNumber: current.accountNumber),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openMoveDialog(
    BuildContext context, {
    required bool toSavings,
    required double maxAmount,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(toSavings ? 'ฝากเงินออม' : 'ถอนเงินออม'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'จำนวนเงิน (บาท)',
              prefixIcon: Icon(Icons.credit_card),
            ),
            validator: (v) {
              final value = double.tryParse(v?.trim() ?? '');
              if (value == null) return 'กรุณากรอกจำนวนเงิน';
              if (value <= 0) return 'จำนวนเงินต้องมากกว่า 0';
              if (value > maxAmount) return 'ยอดเงินไม่เพียงพอ';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, double.parse(controller.text.trim()));
            },
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (amount == null || !context.mounted) return;

    final accountNumber = AuthService.instance.currentAccountNumber!;
    try {
      if (toSavings) {
        await SavingsService.instance.deposit(
          accountNumber: accountNumber,
          amount: amount,
        );
      } else {
        await SavingsService.instance.withdraw(
          accountNumber: accountNumber,
          amount: amount,
        );
      }
      if (context.mounted) {
        showMessage(
          context,
          toSavings ? 'ฝากเงินออมสำเร็จ' : 'ถอนเงินออมสำเร็จ',
        );
      }
    } catch (e) {
      if (context.mounted) showMessage(context, errorMessage(e), error: true);
    }
  }
}

/// การ์ดยอดเงินออม 
class _SavingsBalanceCard extends StatelessWidget {
  final AccountModel account;
  const _SavingsBalanceCard({required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      decoration: BoxDecoration(
        color: brandColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.savings,
                color: Color.fromARGB(255, 6, 6, 6),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'ยอดเงินออม',
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(179, 0, 0, 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(account.savingsBalance),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: Color.fromARGB(255, 0, 0, 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsHistory extends StatelessWidget {
  final String accountNumber;
  const _SavingsHistory({required this.accountNumber});

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
        final items = snap.data!
            .where(
              (t) =>
                  t.type == 'savings_deposit' || t.type == 'savings_withdraw',
            )
            .toList();
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(
              child: Text(
                'ยังไม่มีประวัติเงินออม',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          );
        }

        return Column(
          children: items.map((t) {
            final deposit = t.type == 'savings_deposit';
            return ShadowCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Center(
                      child: Icon(
                        deposit ? Icons.south_west : Icons.north_east,
                        color: deposit ? incomeColor : dangerColor,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deposit ? 'ฝากเงินออม' : 'ถอนเงินออม',
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
                    '${deposit ? '+' : '-'}${formatMoney(t.amount)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: deposit ? incomeColor : dangerColor,
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
