/// ข้อมูลสมาชิกในกลุ่ม 1 คน
class TeamMemberModel {
  final String name;
  final String studentId;
  final int number;

  /// ที่อยู่ไฟล์รูปโปรไฟล์ เช่น 'assets/images/member1.png' (ไม่ใส่ก็ได้)
  final String? imagePath;

  const TeamMemberModel({
    required this.name,
    required this.studentId,
    required this.number,
    this.imagePath,
  });
}
