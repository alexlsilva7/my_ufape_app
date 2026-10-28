import 'package:flutter/material.dart';

import '../../../data/parsers/admin_data.dart';
import 'admin_section.dart';

class AdminRecordsSection extends StatelessWidget {
  const AdminRecordsSection({
    super.key,
    required this.schedule,
    required this.scheduleRows,
    required this.curriculum,
    required this.course,
    required this.searchController,
    required this.selectedProfile,
    required this.selectedPeriod,
    required this.semesterController,
    required this.busy,
    required this.creating,
    required this.onFieldsChanged,
    required this.onOpenEnteredSemester,
    required this.onOpenSemester,
    required this.onEditRecord,
    required this.onDeleteRecord,
    required this.onEditWhole,
    required this.filters,
    required this.saveAction,
  });
  final bool schedule;
  final List<Json> scheduleRows;
  final Json curriculum;
  final Json course;
  final TextEditingController searchController;
  final String selectedProfile;
  final String selectedPeriod;
  final TextEditingController semesterController;
  final bool busy;
  final bool creating;
  final VoidCallback onFieldsChanged;
  final VoidCallback onOpenEnteredSemester;
  final ValueChanged<String> onOpenSemester;
  final ValueChanged<int?> onEditRecord;
  final ValueChanged<int> onDeleteRecord;
  final VoidCallback onEditWhole;
  final Widget filters;
  final Widget saveAction;
  @override
  Widget build(BuildContext context) {
    final list = schedule ? scheduleRows : records(curriculum['subjects']);
    final filtered = list.asMap().entries.where((entry) {
      final row = entry.value;
      final text = '${row['name']} ${row['code']}'.toLowerCase();
      return text.contains(searchController.text.toLowerCase()) &&
          (selectedProfile.isEmpty || row['profile'] == selectedProfile) &&
          (selectedPeriod.isEmpty || '${row['period']}' == selectedPeriod);
    });
    return AdminSectionPage(
      schedule ? 'Oferta semestral' : 'Catálogo de disciplinas',
      [
        if (schedule)
          AdminPanel('Semestre letivo', [
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: TextField(
                    controller: semesterController,
                    decoration: const InputDecoration(
                      labelText: 'AAAA.1 ou AAAA.2',
                    ),
                    onChanged: (_) => onFieldsChanged(),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy || creating ? null : onOpenEnteredSemester,
                  child: const Text('Abrir semestre'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final semester in course['semesters'] as List? ?? [])
                  ActionChip(
                    label: Text('$semester'),
                    onPressed: () => onOpenSemester('$semester'),
                  ),
              ],
            ),
          ]),
        filters,
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.tonalIcon(
              onPressed: busy ? null : () => onEditRecord(null),
              icon: const Icon(Icons.add),
              label: Text(
                schedule ? 'Adicionar turma' : 'Adicionar disciplina',
              ),
            ),
            OutlinedButton.icon(
              onPressed: onEditWhole,
              icon: const Icon(Icons.code),
              label: const Text('Editar JSON completo'),
            ),
            Text('${filtered.length} de ${list.length} registros'),
          ],
        ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nenhum registro para estes filtros.'),
          ),
        for (final entry in filtered)
          Card(
            child: ListTile(
              isThreeLine: true,
              title: Text(
                '${entry.value['code'] ?? ''} · ${entry.value['name'] ?? 'Sem nome'}',
              ),
              subtitle: Text(
                schedule
                    ? '${entry.value['professor'] ?? 'Sem docente'} · Perfil ${entry.value['profile'] ?? '—'} · Período ${entry.value['period'] ?? '—'}\n${records(entry.value['sessions']).map((session) => '${session['day']}ª ${session['time']}').join(' · ')}'
                    : 'Perfil ${entry.value['profile'] ?? '—'} · Período ${entry.value['period'] ?? '—'} · ${object(entry.value['workload'])['total'] ?? '—'}h\n${entry.value['type'] ?? 'Tipo não informado'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: busy ? null : () => onEditRecord(entry.key),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Excluir',
                    onPressed: busy ? null : () => onDeleteRecord(entry.key),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
      action: saveAction,
    );
  }
}
