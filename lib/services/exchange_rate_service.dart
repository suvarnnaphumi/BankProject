import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/exchange_rate_model.dart';

/// เรียก API ภายนอก ExchangeRate-API (https://open.er-api.com) ไม่ต้องใช้ API key ข้อมูลอัปเดตวันละครั้ง
class ExchangeRateService {
  ExchangeRateService._();
  static final instance = ExchangeRateService._();
  static const _url = 'https://open.er-api.com/v6/latest/THB';
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

  ExchangeRateModel? _cache;

  /// ดึงอัตราแลกเปลี่ยนล่าสุด
  Future<ExchangeRateModel> getRates({bool forceRefresh = false}) async {
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

    return _cache = ExchangeRateModel.fromJson(json, currencies.keys);
  }
}
