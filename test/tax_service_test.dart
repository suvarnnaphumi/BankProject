import 'package:bankproject/services/tax_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tax = TaxService.instance;

  test('เงินเดือน 50,000 x 12 + ประกันสังคม 9,000', () {
    // 600,000 - ค่าใช้จ่าย 100,000 - ส่วนตัว 60,000 - ประกันสังคม 9,000 = 431,000
    // ภาษี: 150,000 x 5% = 7,500 + 131,000 x 10% = 13,100 -> 20,600
    final r = tax.calculate(
      const TaxInput(annualIncome: 600000, socialSecurity: 9000),
    );
    expect(r.netIncome, 431000);
    expect(r.totalTax, 20600);
    expect(r.remaining, 579400);
  });

  test('เงินได้น้อย ได้รับยกเว้นภาษี', () {
    // 300,000 - 100,000 - 60,000 = 140,000 <= 150,000
    final r = tax.calculate(const TaxInput(annualIncome: 300000));
    expect(r.netIncome, 140000);
    expect(r.totalTax, 0);
  });

  test('เพดานประกันสังคม / ประกันสุขภาพ / RMF', () {
    final r = tax.calculate(
      const TaxInput(
        annualIncome: 1000000,
        socialSecurity: 50000, // เกิน -> 10,500
        lifeInsurance: 90000,
        healthInsurance: 25000, // ชีวิต+สุขภาพ ไม่เกิน 100,000 -> 10,000
        retirementFunds: 400000, // 30% ของ 1,000,000 = 300,000
      ),
    );
    double of(String label) =>
        r.allowances.firstWhere((a) => a.label == label).amount;
    expect(of('ประกันสังคม'), 10500);
    expect(of('ประกันสุขภาพ'), 10000);
    expect(of('กองทุน RMF/SSF/PVD'), 300000);
  });

  test('บริจาคไม่เกิน 10% ของเงินได้หลังหักลดหย่อน', () {
    // 600,000 - 100,000 - 60,000 = 440,000 -> บริจาคได้สูงสุด 44,000
    final r = tax.calculate(
      const TaxInput(annualIncome: 600000, donation: 100000),
    );
    expect(r.allowances.last.amount, 44000);
    expect(r.netIncome, 396000);
  });

  test('รายได้สูง ถึงขั้น 35%', () {
    // 10,000,000 - 100,000 - 60,000 = 9,840,000
    // 0 + 7,500 + 20,000 + 37,500 + 50,000 + 250,000 + 900,000 + 4,840,000x35%(1,694,000)
    final r = tax.calculate(const TaxInput(annualIncome: 10000000));
    expect(r.totalTax, 2959000);
    expect(r.topRate, 0.35);
  });
}
