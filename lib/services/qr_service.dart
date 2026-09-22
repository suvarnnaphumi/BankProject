/// สร้างข้อความสำหรับ QR code และอ่านเลขบัญชีจาก QR ที่สแกนได้
class QrService {
  QrService._();

  /// ข้อความที่ฝังใน QR code เช่น "MYBANK:1234567890"
  static const String prefix = 'MYBANK:';

  /// เลขบัญชี -> ข้อความที่จะเอาไปสร้าง QR
  static String dataFor(String accountNumber) => '$prefix$accountNumber';

  /// แปลงข้อความที่สแกนได้จาก QR -> เลขบัญชี 10 หลัก (null ถ้าไม่ใช่ QR ของแอพเรา)
  static String? accountNumberFrom(String raw) {
    final text = raw.trim();
    final value = text.startsWith(prefix)
        ? text.substring(prefix.length)
        : text;
    return RegExp(r'^\d{10}$').hasMatch(value) ? value : null;
  }
}
