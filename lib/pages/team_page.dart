import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// หน้าแสดงสมาชิกในกลุ่ม: โชว์ชื่อ-นามสกุล, รหัสนิสิต, เลขที่
class TeamMember {
  final String name; // ชื่อ-นามสกุล
  final String studentId; // รหัสนิสิต
  final int number; // เลขที่

  const TeamMember({
    required this.name,
    required this.studentId,
    required this.number,
  });
}

const teamMembers = <TeamMember>[
  TeamMember(
    name: 'นาย สุวรรณภูมิ พรัดขำ',
    studentId: '6721602733',
    number: 43,
  ),
  TeamMember(
    name: 'นางสาว มิววริช ทศทิศรังสรรค์',
    studentId: '6721602555',
    number: 26,
  ),
];

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมาชิกในกลุ่ม')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final member in teamMembers) _MemberCard(member: member),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final TeamMember member;
  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: brandColor,
              foregroundColor: Colors.white,
              child: const Icon(Icons.person, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('รหัสนิสิต ${member.studentId}'),
                  Text('เลขที่ ${member.number}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
