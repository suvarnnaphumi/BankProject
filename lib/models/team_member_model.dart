/// ข้อมูลสมาชิกในกลุ่ม 1 คน (ใช้ในแท็บสมาชิก ไม่ได้เก็บใน Firestore)
class TeamMemberModel {
  final String name; // ชื่อ-นามสกุล
  final String studentId; // รหัสนิสิต
  final int number; // เลขที่

  const TeamMemberModel({
    required this.name,
    required this.studentId,
    required this.number,
  });
}
