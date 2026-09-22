/// ข้อมูลสมาชิกในกลุ่ม 1 คน
class TeamMemberModel {
  final String name;
  final String studentId;
  final int number;
  final String? imagePath;

  const TeamMemberModel({
    required this.name,
    required this.studentId,
    required this.number,
    this.imagePath,
  });
}
