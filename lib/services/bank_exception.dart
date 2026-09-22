/// ข้อความ error ที่จะโชว์ให้ผู้ใช้เห็นตรงๆ (ใช้ร่วมกันทุก service)
class BankException implements Exception {
  final String message;
  BankException(this.message);
  @override
  String toString() => message;
}
