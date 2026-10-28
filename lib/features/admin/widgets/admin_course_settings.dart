import 'package:flutter/material.dart';

import '../../../data/parsers/admin_data.dart';
import 'admin_section.dart';

class AdminCourseSettings extends StatelessWidget {
  const AdminCourseSettings({
    super.key,
    required this.creating,
    required this.busy,
    required this.course,
    required this.idController,
    required this.nameController,
    required this.shortNameController,
    required this.onFieldsChanged,
    required this.onVisibilityChanged,
    required this.onSemesterVisible,
    required this.onPreferSemester,
    required this.onDelete,
    required this.saveAction,
  });
  final bool creating;
  final bool busy;
  final Json course;
  final TextEditingController idController;
  final TextEditingController nameController;
  final TextEditingController shortNameController;
  final VoidCallback onFieldsChanged;
  final void Function(String, bool) onVisibilityChanged;
  final void Function(String, bool) onSemesterVisible;
  final ValueChanged<String> onPreferSemester;
  final VoidCallback onDelete;
  final Widget saveAction;
  @override
  Widget build(
    BuildContext context,
  ) => AdminSectionPage('Configurações do curso', [
    AdminPanel('Identificação', [
      if (creating)
        TextField(
          controller: idController,
          decoration: const InputDecoration(
            labelText: 'Identificador único',
            hintText: 'ciencia-da-computacao',
          ),
          onChanged: (_) => onFieldsChanged(),
        ),
      TextField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'Nome do curso'),
        onChanged: (_) => onFieldsChanged(),
      ),
      TextField(
        controller: shortNameController,
        decoration: const InputDecoration(labelText: 'Sigla'),
        onChanged: (_) => onFieldsChanged(),
      ),
    ]),
    AdminPanel('Visibilidade para os alunos', [
      for (final entry in {
        'hidden': 'Ocultar este curso',
        'showSchedule': 'Exibir horários',
        'showDisciplines': 'Exibir disciplinas',
        'showMatriz': 'Exibir matriz curricular',
      }.entries)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value),
          value:
              course[entry.key] == true ||
              (entry.key != 'hidden' && course[entry.key] == null),
          onChanged: (value) => onVisibilityChanged(entry.key, value),
        ),
    ]),
    AdminPanel('Semestres disponíveis', [
      const Text(
        'Ative os semestres visíveis. O primeiro será aberto por padrão. Desativar preserva os dados cadastrados.',
      ),
      for (final semester in {
        ...(course['visibleSemesters'] as List? ?? []),
        ...(course['semesters'] as List? ?? []),
      })
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '$semester${(course['visibleSemesters'] as List? ?? []).firstOrNull == semester ? ' · Padrão' : ''}',
          ),
          value: (course['visibleSemesters'] as List? ?? []).contains(semester),
          onChanged: (value) => onSemesterVisible('$semester', value == true),
          secondary: IconButton(
            tooltip: 'Definir como padrão',
            icon: const Icon(Icons.vertical_align_top),
            onPressed: () => onPreferSemester('$semester'),
          ),
        ),
    ]),
    if (!creating)
      AdminPanel('Excluir curso', [
        const Text(
          'Remove este curso, todas as matrizes e todas as ofertas semestrais.',
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Excluir curso…'),
        ),
      ]),
  ], action: saveAction);
}
