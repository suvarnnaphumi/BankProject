import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/transaction_service.dart';
import '../services/tax_service.dart';
import '../widgets/common.dart';

/// หน้าคำนวณภาษีรายได้บุคคลธรรมดา (เงินเดือน)
/// ดึงยอดเงินที่โอนเข้าบัญชีทั้งปีนี้มาเป็นค่าเริ่มต้นของให้อัตโนมัติ
class TaxPage extends StatefulWidget {
  const TaxPage({super.key});

  @override
  State<TaxPage> createState() => _TaxPageState();
}

class _TaxPageState extends State<TaxPage> {
  late final Future<double> _incomeFuture;

  @override
  void initState() {
    super.initState();
    _incomeFuture = TransactionService.instance.incomeThisYear(
      AuthService.instance.currentAccountNumber!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คำนวณภาษี')),
      body: FutureBuilder<double>(
        future: _incomeFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // ดึงไม่สำเร็จก็ไม่เป็นไร ให้เริ่มจาก 0 แล้วกรอกเองได้
          return _TaxCalculator(initialIncome: snap.data ?? 0);
        },
      ),
    );
  }
}

final _baht = NumberFormat('#,##0');

class _TaxCalculator extends StatefulWidget {
  final double initialIncome;
  const _TaxCalculator({required this.initialIncome});

  @override
  State<_TaxCalculator> createState() => _TaxCalculatorState();
}

class _TaxCalculatorState extends State<_TaxCalculator> {
  late final _income = TextEditingController(
    text: widget.initialIncome > 0
        ? widget.initialIncome.toStringAsFixed(2)
        : '',
  );
  final _socialSecurity = TextEditingController();
  final _lifeInsurance = TextEditingController();
  final _healthInsurance = TextEditingController();
  final _retirementFunds = TextEditingController();
  final _homeLoanInterest = TextEditingController();
  final _donation = TextEditingController();

  bool _hasSpouse = false;
  int _children = 0;
  int _parents = 0;

  @override
  void dispose() {
    for (final c in [
      _income,
      _socialSecurity,
      _lifeInsurance,
      _healthInsurance,
      _retirementFunds,
      _homeLoanInterest,
      _donation,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: Icon(icon),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = TaxService.instance.calculate(
      TaxInput(
        annualIncome: _num(_income),
        hasSpouse: _hasSpouse,
        children: _children,
        parents: _parents,
        socialSecurity: _num(_socialSecurity),
        lifeInsurance: _num(_lifeInsurance),
        healthInsurance: _num(_healthInsurance),
        retirementFunds: _num(_retirementFunds),
        homeLoanInterest: _num(_homeLoanInterest),
        donation: _num(_donation),
      ),
    );
    final yearTh = DateTime.now().year + 543; // ปี พ.ศ.

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(
          'ปีภาษี $yearTh  •  รายได้ประเภทเงินเดือน',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 8),

        // กรอกข้อมูล
        const SectionLabel('รายได้ทั้งปี (ขั้นที่ 1)'),
        _field(
          _income,
          'รายได้ทั้งปี (บาท)',
          Icons.payments,
          helper: widget.initialIncome > 0
              ? 'ดึงยอดเงินโอนเข้าบัญชีปีนี้มาให้ (สามารถแก้ไขได้ตามจริง)'
              : null,
        ),
        const SectionLabel('ค่าลดหย่อนครอบครัว (ขั้นที่ 2)'),
        ShadowCard(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _RowLabel('คู่สมรสไม่มีรายได้', '60,000 บาท'),
                  ),
                  Switch(
                    value: _hasSpouse,
                    activeTrackColor: brandColor,
                    onChanged: (v) => setState(() => _hasSpouse = v),
                  ),
                ],
              ),
              _Counter(
                label: 'บุตร',
                hint: 'คนละ 30,000 บาท',
                value: _children,
                max: 10,
                onChanged: (v) => setState(() => _children = v),
              ),
              _Counter(
                label: 'บิดามารดาอายุ 60 ปีขึ้นไป',
                hint: 'คนละ 30,000 บาท (สูงสุด 4 คน)',
                value: _parents,
                max: TaxService.maxParents,
                onChanged: (v) => setState(() => _parents = v),
              ),
            ],
          ),
        ),
        const SectionLabel('ค่าลดหย่อนอื่นๆ(ถ้ามี) (ขั้นที่ 3)'),
        _field(
          _socialSecurity,
          'เงินสมทบประกันสังคม',
          Icons.badge,
          helper: 'สูงสุด ${_baht.format(TaxService.maxSocialSecurity)} บาท',
        ),
        _field(
          _lifeInsurance,
          'เบี้ยประกันชีวิต',
          Icons.favorite,
          helper: 'สูงสุด 100,000 บาท',
        ),
        _field(
          _healthInsurance,
          'เบี้ยประกันสุขภาพตนเอง',
          Icons.health_and_safety,
          helper: 'สูงสุด 25,000 บาท (รวมกับประกันชีวิตไม่เกิน 100,000)',
        ),
        _field(
          _retirementFunds,
          'กองทุน RMF / SSF / สำรองเลี้ยงชีพ',
          Icons.savings,
          helper: 'ไม่เกิน 30% ของรายได้ และรวมกันไม่เกิน 500,000 บาท',
        ),
        _field(
          _homeLoanInterest,
          'ดอกเบี้ยเงินกู้ซื้อบ้าน',
          Icons.house,
          helper: 'สูงสุด 100,000 บาท',
        ),
        _field(
          _donation,
          'เงินบริจาค',
          Icons.volunteer_activism,
          helper: 'ไม่เกิน 10% ของรายได้หลังหักค่าใช้จ่ายและค่าลดหย่อน',
        ),

        //ผลลัพธ์
        const SizedBox(height: 8),
        const SectionLabel('วิธีคำนวณ (ขั้นที่ 4)'),
        _StepsCard(result: result),
        const SizedBox(height: 8),
        const SectionLabel('คิดภาษีแบบขั้นบันได (ขั้นที่ 5)'),
        _BracketTable(result: result),
        const SizedBox(height: 8),
        _TaxSummary(result: result, yearTh: yearTh),
        const SizedBox(height: 16),
        _RemainingCard(result: result),
        const SizedBox(height: 16),
        const Text(
          'ตัวเลขนี้เป็นการประมาณการเบื้องต้นเพื่อวางแผนการเงินเท่านั้น '
          'ไม่ใช่คำแนะนำทางภาษีที่เป็นทางการ ควรตรวจสอบกับกรมสรรพากร '
          'หรือผู้เชี่ยวชาญด้านภาษีอีกครั้งก่อนยื่นแบบจริง',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }
}

//ส่วนกรอกข้อมูล

class _RowLabel extends StatelessWidget {
  final String title;
  final String hint;
  const _RowLabel(this.title, this.hint);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(
            hint,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final String hint;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _Counter({
    required this.label,
    required this.hint,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _RowLabel(label, hint)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

//แสดงผล

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool indent;
  final Color? color;

  const _AmountRow(this.label, this.value, {this.indent = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: indent ? 14 : 15,
      color: color ?? (indent ? Colors.black54 : Colors.black),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 32 : 0, 3, 0, 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// หัวข้อขั้นตอน มีเลขในวงกลม
class _StepTitle extends StatelessWidget {
  final int step;
  final String text;
  final String value;
  final bool bold;

  const _StepTitle(this.step, this.text, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 15,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: brandColor,
            child: Text(
              '$step',
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

///ขั้นที่ 1-4: รายได้, หักค่าใช้จ่าย, หักค่าลดหย่อน, รายได้สุทธิ
class _StepsCard extends StatelessWidget {
  final TaxResult result;
  const _StepsCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return ShadowCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          _StepTitle(1, 'รายได้ทั้งปี', formatMoney(result.totalIncome)),
          const SizedBox(height: 4),
          _StepTitle(
            2,
            'หักค่าใช้จ่าย 50%',
            '-${formatMoney(result.expenseDeduction)}',
          ),
          const _AmountRow('(ไม่เกิน 100,000 บาท)', '', indent: true),
          const SizedBox(height: 4),
          _StepTitle(
            3,
            'หักค่าลดหย่อน',
            '-${formatMoney(result.totalAllowances)}',
          ),
          for (final a in result.allowances)
            _AmountRow(a.label, formatMoney(a.amount), indent: true),
          const Divider(height: 24),
          _StepTitle(
            4,
            'รายได้สุทธิ',
            formatMoney(result.netIncome),
            bold: true,
          ),
          const _AmountRow('(ยอดที่นำไปคิดภาษี)', '', indent: true),
        ],
      ),
    );
  }
}

///ขั้นที่ 5: ตารางขั้นบันไดภาษี แสดงครบทุกขั้น ขั้นที่ไม่ถึงเป็นสีจาง
class _BracketTable extends StatelessWidget {
  final TaxResult result;
  const _BracketTable({required this.result});

  @override
  Widget build(BuildContext context) {
    const header = TextStyle(fontSize: 13, color: Colors.black54);

    return ShadowCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(flex: 5, child: Text('รายได้สุทธิ', style: header)),
              Expanded(
                flex: 2,
                child: Text(
                  'อัตรา',
                  style: header,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text('ภาษี', style: header, textAlign: TextAlign.right),
              ),
            ],
          ),
          const Divider(),
          for (final b in result.brackets) _BracketRow(b),
          const Divider(),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'รวมภาษีทุกขั้น',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                formatMoney(result.totalTax),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BracketRow extends StatelessWidget {
  final TaxBracketResult b;
  const _BracketRow(this.b);

  @override
  Widget build(BuildContext context) {
    final from = b.bracket.from;
    final to = b.bracket.to;
    final start = from == 0 ? '0' : _baht.format(from + 1);
    final range = to == null
        ? '${_baht.format(from + 1)} ขึ้นไป'
        : '$start - ${_baht.format(to)}';
    final color = b.reached ? Colors.black : Colors.black26;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(range, style: TextStyle(fontSize: 14, color: color)),
                if (b.reached)
                  Text(
                    'คิดจาก ${formatMoney(b.taxableAmount)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              b.bracket.rate == 0
                  ? 'ยกเว้น'
                  : '${(b.bracket.rate * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: color),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatMoney(b.tax),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

///ผลสุดท้าย
class _TaxSummary extends StatelessWidget {
  final TaxResult result;
  final int yearTh;
  const _TaxSummary({required this.result, required this.yearTh});

  @override
  Widget build(BuildContext context) {
    final percent = NumberFormat('#,##0.00');
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
          Text(
            'ภาษีสุทธิที่ต้องเสีย ปี $yearTh',
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            formatMoney(result.totalTax),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
          ),
          if (result.totalTax == 0 && result.totalIncome > 0)
            const Text(
              'รายได้สุทธิไม่เกิน 150,000 บาท ได้รับยกเว้นภาษี',
              style: TextStyle(fontSize: 14),
            ),
          const SizedBox(height: 12),
          _AmountRow(
            'อัตราภาษีเฉลี่ย',
            '${percent.format(result.effectiveRate * 100)}%',
          ),
          _AmountRow(
            'ขั้นภาษีสูงสุดที่ถึง',
            '${(result.topRate * 100).toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }
}

class _RemainingCard extends StatelessWidget {
  final TaxResult result;
  const _RemainingCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เหลือใช้หลังหักภาษี (ต่อปี)',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          Text(
            formatMoney(result.remaining),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _AmountRow(
            'เฉลี่ยต่อเดือน',
            formatMoney(result.remainingPerMonth),
            color: Colors.white,
          ),
          _AmountRow(
            'คิดจาก',
            '${formatMoney(result.totalIncome)} - ${formatMoney(result.totalTax)}',
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}
