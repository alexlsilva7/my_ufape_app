import 'package:flutter/material.dart';

import 'admin_section.dart';
import 'admin_navigation.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({
    super.key,
    required this.courseName,
    required this.courseCount,
    required this.subjectCount,
    required this.profileCount,
    required this.offeringCount,
    required this.dataSource,
    required this.isLocal,
    required this.onNavigate,
  });
  final String courseName;
  final int courseCount;
  final int subjectCount;
  final int profileCount;
  final int offeringCount;
  final String dataSource;
  final bool isLocal;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => AdminSectionPage('Visão geral', [
    AdminPanel(courseName.isEmpty ? 'Bem-vindo à administração' : courseName, [
      Text(
        '$courseCount cursos · $subjectCount disciplinas · $profileCount perfis · $offeringCount turmas',
      ),
      Text('Fonte dos dados: $dataSource'),
      Text(
        isLocal
            ? 'Revise os rascunhos e as importações antes de salvar. As alterações ficam somente neste dispositivo.'
            : 'Revise os rascunhos e as importações antes de salvar. As alterações só são publicadas ao salvar no servidor.',
      ),
    ]),
    Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final key in [
          'settings',
          'catalog',
          'structure',
          'schedule',
          'import',
          'feedback',
        ])
          OutlinedButton.icon(
            onPressed: () => onNavigate(key),
            icon: Icon(adminSections[key]!.$2),
            label: Text(adminSections[key]!.$1),
          ),
      ],
    ),
  ]);
}
