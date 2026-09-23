/// คำนวณภาษีเงิน
library;

import 'dart:math';

/// ขั้นบันไดภาษี 1 ขั้น
class TaxBracket {
  final double from;
  final double? to;
  final double rate;

  const TaxBracket({required this.from, this.to, required this.rate});
}

/// ผลการคิดภาษีใน 1 ขั้น
class TaxBracketResult {
  final TaxBracket bracket;
  final double taxableAmount;
  final double tax;

  const TaxBracketResult({
    required this.bracket,
    required this.taxableAmount,
    required this.tax,
  });

  bool get reached => taxableAmount > 0;
}

/// ข้อมูลที่ผู้ใช้กรอก
class TaxInput {
  final double annualIncome;
  final bool hasSpouse;
  final int children;
  final int parents;
  final double socialSecurity;
  final double lifeInsurance;
  final double healthInsurance;
  final double retirementFunds;
  final double homeLoanInterest;
  final double donation;

  const TaxInput({
    required this.annualIncome,
    this.hasSpouse = false,
    this.children = 0,
    this.parents = 0,
    this.socialSecurity = 0,
    this.lifeInsurance = 0,
    this.healthInsurance = 0,
    this.retirementFunds = 0,
    this.homeLoanInterest = 0,
    this.donation = 0,
  });
}

class TaxAllowance {
  final String label;
  final double amount;
  const TaxAllowance(this.label, this.amount);
}

class TaxResult {
  final double totalIncome;
  final double expenseDeduction;
  final List<TaxAllowance> allowances;
  final double netIncome;
  final List<TaxBracketResult> brackets;
  final double totalTax;

  const TaxResult({
    required this.totalIncome,
    required this.expenseDeduction,
    required this.allowances,
    required this.netIncome,
    required this.brackets,
    required this.totalTax,
  });

  double get totalAllowances => allowances.fold(0, (sum, a) => sum + a.amount);

  double get remaining => totalIncome - totalTax;
  double get remainingPerMonth => remaining / 12;

  double get effectiveRate => totalIncome <= 0 ? 0 : totalTax / totalIncome;

  double get topRate => brackets
      .lastWhere((b) => b.reached, orElse: () => brackets.first)
      .bracket
      .rate;
}

class TaxService {
  TaxService._();
  static final instance = TaxService._();

  static const double maxExpenseDeduction = 100000;
  static const double personalAllowance = 60000;
  static const double spouseAllowance = 60000;
  static const double childAllowance = 30000;
  static const double parentAllowance = 30000;
  static const int maxParents = 4;
  static const double maxSocialSecurity = 10500;
  static const double maxLifeInsurance = 100000;
  static const double maxHealthInsurance = 25000;
  static const double maxLifeAndHealth = 100000; 
  static const double maxRetirementFunds = 500000;
  static const double retirementIncomeRatio = 0.30;
  static const double maxHomeLoanInterest = 100000;
  static const double donationRatio = 0.10;
  
  static const List<TaxBracket> brackets = [
    TaxBracket(from: 0, to: 150000, rate: 0),
    TaxBracket(from: 150000, to: 300000, rate: 0.05),
    TaxBracket(from: 300000, to: 500000, rate: 0.10),
    TaxBracket(from: 500000, to: 750000, rate: 0.15),
    TaxBracket(from: 750000, to: 1000000, rate: 0.20),
    TaxBracket(from: 1000000, to: 2000000, rate: 0.25),
    TaxBracket(from: 2000000, to: 5000000, rate: 0.30),
    TaxBracket(from: 5000000, rate: 0.35),
  ];

  static double _cap(double value, double limit) =>
      value.clamp(0, max(0, limit)).toDouble();

  TaxResult calculate(TaxInput input) {
    final income = max(0.0, input.annualIncome);

    // ขั้นที่ 2
    final expense = min(income * 0.5, maxExpenseDeduction);

    // ขั้นที่ 3
    final parents = input.parents.clamp(0, maxParents);
    final life = _cap(input.lifeInsurance, maxLifeInsurance);
    final health = _cap(
      input.healthInsurance,
      min(maxHealthInsurance, maxLifeAndHealth - life),
    );
    final retirement = _cap(
      input.retirementFunds,
      min(maxRetirementFunds, income * retirementIncomeRatio),
    );

    final allowances = <TaxAllowance>[
      const TaxAllowance('ส่วนตัว', personalAllowance),
      if (input.hasSpouse)
        const TaxAllowance('คู่สมรส (ไม่มีเงินได้)', spouseAllowance),
      if (input.children > 0)
        TaxAllowance(
          'บุตร ${input.children} คน',
          input.children * childAllowance,
        ),
      if (parents > 0)
        TaxAllowance('บิดามารดา $parents คน', parents * parentAllowance),
      if (input.socialSecurity > 0)
        TaxAllowance(
          'ประกันสังคม',
          _cap(input.socialSecurity, maxSocialSecurity),
        ),
      if (life > 0) TaxAllowance('ประกันชีวิต', life),
      if (health > 0) TaxAllowance('ประกันสุขภาพ', health),
      if (retirement > 0) TaxAllowance('กองทุน RMF/SSF/PVD', retirement),
      if (input.homeLoanInterest > 0)
        TaxAllowance(
          'ดอกเบี้ยเงินกู้ซื้อบ้าน',
          _cap(input.homeLoanInterest, maxHomeLoanInterest),
        ),
    ];

    final beforeDonation = max(
      0.0,
      income - expense - allowances.fold(0.0, (sum, a) => sum + a.amount),
    );
    final donation = _cap(input.donation, beforeDonation * donationRatio);
    if (donation > 0) allowances.add(TaxAllowance('เงินบริจาค', donation));

    // ขั้นที่ 4
    final netIncome = beforeDonation - donation;

    // ขั้นที่ 5
    final results = <TaxBracketResult>[];
    for (final b in brackets) {
      final width = (b.to ?? double.infinity) - b.from; // ความกว้างของขั้น
      final taxable = (netIncome - b.from).clamp(0, width).toDouble();
      results.add(
        TaxBracketResult(
          bracket: b,
          taxableAmount: taxable,
          tax: taxable * b.rate,
        ),
      );
    }

    return TaxResult(
      totalIncome: income,
      expenseDeduction: expense,
      allowances: allowances,
      netIncome: netIncome,
      brackets: results,
      totalTax: results.fold(0.0, (sum, r) => sum + r.tax),
    );
  }
}
