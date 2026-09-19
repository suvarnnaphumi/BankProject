/// อัตราแลกเปลี่ยนที่ได้จาก API ExchangeRate-API (https://open.er-api.com)
class ExchangeRateModel {
  /// อัตรา "1 บาท = x สกุลเงินนั้น" เช่น rates['USD'] = 0.0308
  final Map<String, double> rates;
  final DateTime lastUpdate;

  ExchangeRateModel({required this.rates, required this.lastUpdate});

  /// แปลง JSON จาก API (เก็บเฉพาะสกุลเงินที่อยู่ใน [codes])
  factory ExchangeRateModel.fromJson(
    Map<String, dynamic> json,
    Iterable<String> codes,
  ) {
    final allRates = (json['rates'] as Map<String, dynamic>).map(
      (code, value) => MapEntry(code, (value as num).toDouble()),
    );
    return ExchangeRateModel(
      rates: {
        for (final code in codes)
          if (allRates.containsKey(code)) code: allRates[code]!,
      },
      lastUpdate: DateTime.fromMillisecondsSinceEpoch(
        (json['time_last_update_unix'] as int) * 1000,
      ),
    );
  }

  /// 1 หน่วยของสกุลเงินนั้น = กี่บาท (เช่น 1 USD = 32.45 บาท)
  double thbPerUnit(String currency) => 1 / rates[currency]!;

  /// แปลงเงินบาท -> สกุลเงินอื่น
  double fromThb(double thb, String currency) => thb * rates[currency]!;

  /// แปลงสกุลเงินอื่น -> เงินบาท
  double toThb(double amount, String currency) => amount / rates[currency]!;
}
