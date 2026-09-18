import 'dart:convert';

import 'package:http/http.dart' as http;

/// ข้อมูลอัตราแลกเปลี่ยนที่ได้จาก API
class ExchangeRates {
  /// อัตรา "1 บาท = x สกุลเงินนั้น" เช่น rates['USD'] = 0.0308
  final Map<String, double> rates;
  final DateTime lastUpdate;

  ExchangeRates({required this.rates, required this.lastUpdate});

  /// 1 หน่วยของสกุลเงินนั้น = กี่บาท (เช่น 1 USD = 32.45 บาท)
  double thbPerUnit(String currency) => 1 / rates[currency]!;

  /// แปลงเงินบาท -> สกุลเงินอื่น
  double fromThb(double thb, String currency) => thb * rates[currency]!;

  /// แปลงสกุลเงินอื่น -> เงินบาท
  double toThb(double amount, String currency) => amount / rates[currency]!;
}

/// เรียก API ภายนอก ExchangeRate-API (https://open.er-api.com)
/// ฟรี ไม่ต้องใช้ API key ข้อมูลอัปเดตวันละครั้ง
class ExchangeRateService {
  ExchangeRateService._();
  static final instance = ExchangeRateService._();

  static const _url = 'https://open.er-api.com/v6/latest/THB';

  /// สกุลเงินที่จะโชว์ในแอพ พร้อมชื่อภาษาไทยและธง
  static const currencies = <String, String>{
    'USD': '🇺🇸 ดอลลาร์สหรัฐ',
    'EUR': '🇪🇺 ยูโร',
    'JPY': '🇯🇵 เยนญี่ปุ่น',
    'CNY': '🇨🇳 หยวนจีน',
    'GBP': '🇬🇧 ปอนด์สเตอร์ลิง',
    'KRW': '🇰🇷 วอนเกาหลีใต้',
    'SGD': '🇸🇬 ดอลลาร์สิงคโปร์',
    'HKD': '🇭🇰 ดอลลาร์ฮ่องกง',
    'AUD': '🇦🇺 ดอลลาร์ออสเตรเลีย',
    'LAK': '🇱🇦 กีบลาว',
  };

  ExchangeRates? _cache;

  /// ดึงอัตราแลกเปลี่ยนล่าสุด (เก็บ cache ไว้ จะได้ไม่ต้องเรียก API ซ้ำทุกครั้ง)
  Future<ExchangeRates> getRates({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;

    final http.Response response;
    try {
      response = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw Exception('เชื่อมต่ออินเทอร์เน็ตไม่ได้ กรุณาลองใหม่');
    }

    if (response.statusCode != 200) {
      throw Exception('เรียก API ไม่สำเร็จ (HTTP ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['result'] != 'success') {
      throw Exception('API ตอบกลับผิดพลาด: ${json['error-type']}');
    }

    final allRates = (json['rates'] as Map<String, dynamic>).map(
      (code, value) => MapEntry(code, (value as num).toDouble()),
    );
    // เก็บเฉพาะสกุลเงินที่แอพใช้
    final rates = {
      for (final code in currencies.keys)
        if (allRates.containsKey(code)) code: allRates[code]!,
    };

    return _cache = ExchangeRates(
      rates: rates,
      lastUpdate: DateTime.fromMillisecondsSinceEpoch(
        (json['time_last_update_unix'] as int) * 1000,
      ),
    );
  }
}
