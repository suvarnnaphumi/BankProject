import 'package:flutter/material.dart';

import '../models/team_member_model.dart';
import '../widgets/common.dart';

/// แท็บสมาชิกในกลุ่ม: โชว์ชื่อ-นามสกุล, รหัสนิสิต, เลขที่
// แก้ข้อมูลสมาชิกในกลุ่มตรงนี้
const teamMembers = <TeamMemberModel>[
  TeamMemberModel(
    name: 'นาย สุวรรณภูมิ พรัดขำ',
    studentId: '6721602733',
    number: 43,
  ),
  TeamMemberModel(
    name: 'นางสาว มิววริช ทศทิศรังสรรค์',
    studentId: '6721602555',
    number: 26,
  ),
];

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final member in teamMembers)
          ShadowCard(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'รหัสนิสิต  ${member.studentId}',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'เลขที่ ${member.number}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
