/// สร้างข้อความสำหรับ QR code และอ่านเลขบัญชีจาก QR ที่สแกนได้
class QrService {
  QrService._();

  static const String prefix = 'MYBANK:';
  static String dataFor(String accountNumber) => '$prefix$accountNumber';

  static String? accountNumberFrom(String raw) {
    final text = raw.trim();
    final value = text.startsWith(prefix)
        ? text.substring(prefix.length)
        : text;
    return RegExp(r'^\d{10}$').hasMatch(value) ? value : null;
  }
}
