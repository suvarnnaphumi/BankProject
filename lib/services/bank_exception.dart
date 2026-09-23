/// ข้อความ error ใช้ร่วมกันทุก service
class BankException implements Exception {
  final String message;
  BankException(this.message);
  @override
  String toString() => message;
}
