import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/exchange_rate_service.dart';
import '../widgets/common.dart';

/// หน้าอัตราแลกเปลี่ยน: ดึงข้อมูลจาก API ภายนอก + เครื่องแปลงค่าเงิน
class ExchangeRatePage extends StatefulWidget {
  /// ยอดเงินในบัญชี ใช้เป็นค่าเริ่มต้นของเครื่องแปลงค่าเงิน
  final double balance;
  const ExchangeRatePage({super.key, required this.balance});

  @override
  State<ExchangeRatePage> createState() => _ExchangeRatePageState();
}

class _ExchangeRatePageState extends State<ExchangeRatePage> {
  late Future<ExchangeRates> _future;

  @override
  void initState() {
    super.initState();
    _future = ExchangeRateService.instance.getRates();
  }

  Future<void> _refresh() async {
    final future = ExchangeRateService.instance.getRates(forceRefresh: true);
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder จะโชว์หน้า error ให้เอง
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('อัตราแลกเปลี่ยน')),
      body: FutureBuilder<ExchangeRates>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refresh,
            );
          }
          final rates = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Converter(rates: rates, initialThb: widget.balance),
                const SizedBox(height: 24),
                const Text(
                  'อัตราแลกเปลี่ยนวันนี้',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'อัปเดตล่าสุด '
                  '${DateFormat('dd/MM/yyyy HH:mm').format(rates.lastUpdate)}'
                  '  •  ดึงข้อมูลจาก open.er-api.com',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                for (final code in rates.rates.keys)
                  _RateTile(code: code, rates: rates),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RateTile extends StatelessWidget {
  final String code;
  final ExchangeRates rates;
  const _RateTile({required this.code, required this.rates});

  @override
  Widget build(BuildContext context) {
    final name = ExchangeRateService.currencies[code]!;
    final thb = rates.thbPerUnit(code);
    // สกุลที่ค่าต่ำกว่า 1 บาท (เช่น วอน, กีบ) โชว์ทศนิยม 4 ตำแหน่ง
    final text = thb < 1
        ? '${NumberFormat('#,##0.0000').format(thb)} ฿'
        : formatMoney(thb);
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text('1 $code'),
        trailing: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// เครื่องแปลงค่าเงิน บาท <-> สกุลเงินที่เลือก
class _Converter extends StatefulWidget {
  final ExchangeRates rates;
  final double initialThb;
  const _Converter({required this.rates, required this.initialThb});

  @override
  State<_Converter> createState() => _ConverterState();
}

class _ConverterState extends State<_Converter> {
  late final _amount = TextEditingController(
    text: widget.initialThb.toStringAsFixed(2),
  );
  String _currency = 'USD';
  bool _thbToForeign = true; // true = บาท -> ต่างประเทศ

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final result = _thbToForeign
        ? widget.rates.fromThb(amount, _currency)
        : widget.rates.toThb(amount, _currency);
    final fromCode = _thbToForeign ? 'THB' : _currency;
    final toCode = _thbToForeign ? _currency : 'THB';

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'แปลงค่าเงิน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(
                labelText: 'สกุลเงิน',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: [
                for (final code in widget.rates.rates.keys)
                  DropdownMenuItem(
                    value: code,
                    child: Text(
                      '$code  ${ExchangeRateService.currencies[code]}',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _currency = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'จำนวน ($fromCode)',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  tooltip: 'สลับทิศทาง',
                  icon: const Icon(Icons.swap_horiz, color: brandColor),
                  onPressed: () =>
                      setState(() => _thbToForeign = !_thbToForeign),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '= ${NumberFormat('#,##0.00').format(result)} $toCode',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: brandColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.black38),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }
}
