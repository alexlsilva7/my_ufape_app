import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import 'academic_motion.dart';

String hoursLabel(num value) => value == value.roundToDouble()
    ? '${value.toInt()}'
    : value.toStringAsFixed(1);

bool isCatalogElective(Subject subject) =>
    subject.isElective ||
    subject.raw['period'] == 0 ||
    subject.raw['period'] == '0';

const statusNames = {
  'pendente': 'Pendente',
  'cursando': 'Cursando',
  'concluido': 'Concluída',
};

Color statusColor(String status) => switch (status) {
  'concluido' => const Color(0xff059669),
  'cursando' => const Color(0xff4f46e5),
  _ => const Color(0xff64748b),
};

class AcademicEmpty extends StatelessWidget {
  const AcademicEmpty(
    this.message, {
    super.key,
    this.icon = Icons.menu_book_outlined,
  });
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Icon(icon, size: 46, color: Theme.of(context).colorScheme.outline),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class AcademicChip extends StatelessWidget {
  const AcademicChip(this.label, {super.key, this.color, this.icon});
  final String label;
  final Color? color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final shade = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: shade.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (icon != null) Icon(icon, size: 13, color: shade),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: shade,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AcademicDropdown<T> extends StatelessWidget {
  const AcademicDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
    this.width = 180,
  });
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  final String label;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownButtonFormField<T>(
      initialValue: items.containsKey(value) ? value : items.keys.first,
      key: ValueKey('$label:$value:${items.keys.join(',')}'),
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (item) {
        if (item != null) onChanged(item);
      },
    ),
  );
}

Future<void> showAcademicDetails(
  BuildContext context,
  AppState state,
  Subject initialSubject, {
  bool editable = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  sheetAnimationStyle: academicDialogMotion(context),
  constraints: const BoxConstraints(maxWidth: 760),
  builder: (context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final subject = editable
          ? state.subjects
                    .where((s) => s.id == initialSubject.id)
                    .firstOrNull ??
                initialSubject
          : initialSubject;
      final raw = subject.raw;
      final contents = asMap(state.courseDetails['contents']);
      final content = asList(contents['disciplinas'] ?? contents['subjects'])
          .map(asMap)
          .where(
            (item) =>
                (subject.displayCode?.isNotEmpty == true &&
                    normalized(textOf(item['codigo'] ?? item['code'])) ==
                        normalized(subject.displayCode!)) ||
                normalized(textOf(item['nome'] ?? item['name'])) ==
                    normalized(subject.displayName),
          )
          .firstOrNull;
      final program = textOf(
        raw['conteudo_programatico'] ?? content?['conteudo_programatico'],
      );
      final description =
          subject.electiveSelection?.desc ??
          (subject.desc.isNotEmpty ? subject.desc : textOf(content?['ementa']));
      final relations = <String, dynamic>{
        'Pré-requisitos': raw['prerequisites'] ?? subject.prereqs,
        'Correquisitos': raw['corequisites'],
        'Equivalências': raw['equivalences'],
      };
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.displayCode ?? 'DISCIPLINA',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Fechar detalhes',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                subject.displayName,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AcademicChip(
                    '${hoursLabel(subject.displayHours)} horas',
                    icon: Icons.schedule,
                  ),
                  AcademicChip(
                    subject.period == 0
                        ? 'Optativa'
                        : '${subject.period ?? '—'}º período',
                  ),
                  AcademicChip(subject.type),
                  if (subject.profile != null && subject.profile!.isNotEmpty)
                    AcademicChip(subject.profile!),
                  if (raw['credits'] != null)
                    AcademicChip('${raw['credits']} créditos'),
                ],
              ),
              if (editable) ...[
                const SizedBox(height: 24),
                Text(
                  'Meu progresso',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: statusNames.entries
                      .map(
                        (entry) => ButtonSegment(
                          value: entry.key,
                          label: Text(entry.value),
                        ),
                      )
                      .toList(),
                  selected: {state.subjectStatus(subject)},
                  onSelectionChanged: (value) =>
                      state.setSubjectStatus(subject, value.first),
                ),
                AcademicFormSection(
                  identity: state.subjectStatus(subject) == 'concluido',
                  child: state.subjectStatus(subject) != 'concluido'
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextFormField(
                            key: ValueKey('grade-${subject.id}'),
                            initialValue: state.grade(subject),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Nota (0 a 10)',
                              prefixIcon: Icon(Icons.star_outline),
                            ),
                            onChanged: (value) {
                              final grade = double.tryParse(
                                value.replaceAll(',', '.'),
                              );
                              if (value.isEmpty ||
                                  (grade != null &&
                                      grade >= 0 &&
                                      grade <= 10)) {
                                state.setGrade(
                                  subject,
                                  value.replaceAll(',', '.'),
                                );
                              }
                            },
                          ),
                        ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Ementa',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SelectableText(
                description.isNotEmpty
                    ? description
                    : 'Ementa não detalhada no documento.',
                style: const TextStyle(height: 1.6),
              ),
              if (program.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Conteúdo programático',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SelectableText(program),
              ],
              for (final entry in relations.entries)
                if (entry.value is List &&
                    (entry.value as List).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (final relation in entry.value as List)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(_relationLabel(relation, state)),
                    ),
                ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar detalhes'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);

String _relationLabel(dynamic relation, AppState state) {
  if (relation is Map) {
    return [
      relation['code'],
      relation['name'],
    ].where((v) => v != null && v.toString().isNotEmpty).join(' • ');
  }
  final id = relation.toString();
  for (final subject in state.subjects) {
    if (subject.id == id || subject.code == id) {
      return '${subject.code ?? ''} • ${subject.name}';
    }
  }
  return id;
}

Subject? subjectForOffering(AppState state, Discipline offering) {
  for (final subject in state.catalogSubjects) {
    if ((offering.code != null && offering.code == subject.code) ||
        normalized(offering.name) == normalized(subject.name)) {
      return subject;
    }
  }
  return null;
}
