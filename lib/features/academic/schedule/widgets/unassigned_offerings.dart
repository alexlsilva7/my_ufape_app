import 'package:flutter/material.dart';

import '../../../../core/models.dart';

class ScheduleUnassignedOfferings extends StatelessWidget {
  const ScheduleUnassignedOfferings({
    super.key,
    required this.selected,
    required this.onDetails,
    required this.onToggle,
  });
  final List<Discipline> selected;
  final ValueChanged<Discipline> onDetails;
  final ValueChanged<Discipline> onToggle;
  @override
  Widget build(BuildContext context) {
    final items = selected
        .where(
          (d) =>
              d.sessions.isEmpty ||
              d.sessions.every(
                (s) =>
                    s.startMinutes == null ||
                    s.endMinutes == null ||
                    s.day < 1 ||
                    s.day > 6,
              ),
        )
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Disciplinas sem horário definido',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        for (final item in items)
          ListTile(
            title: Text(item.name),
            subtitle: Text(item.professor ?? 'Horário a confirmar'),
            leading: const Icon(Icons.schedule_outlined),
            onTap: () => onDetails(item),
            trailing: IconButton(
              tooltip: 'Remover disciplina',
              onPressed: () => onToggle(item),
              icon: const Icon(Icons.close),
            ),
          ),
      ],
    );
  }
}
