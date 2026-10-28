import 'package:flutter/material.dart';

import '../../../data/parsers/admin_data.dart';
import 'admin_section.dart';

class AdminStructureSection extends StatelessWidget {
  const AdminStructureSection({
    super.key,
    required this.curriculum,
    required this.selectedProfile,
    required this.selectedPeriod,
    required this.searchController,
    required this.onEditProfile,
    required this.onEditRequirements,
    required this.onEditWhole,
    required this.onDeleteProfile,
    required this.onEditLinks,
    required this.onActiveProfileChanged,
    required this.filters,
    required this.saveAction,
  });
  final Json curriculum;
  final String selectedProfile;
  final String selectedPeriod;
  final TextEditingController searchController;
  final ValueChanged<Json?> onEditProfile;
  final VoidCallback onEditRequirements;
  final VoidCallback onEditWhole;
  final ValueChanged<Json> onDeleteProfile;
  final ValueChanged<Json> onEditLinks;
  final ValueChanged<String> onActiveProfileChanged;
  final Widget filters;
  final Widget saveAction;
  @override
  Widget build(
    BuildContext context,
  ) => AdminSectionPage('Estrutura curricular e perfis', [
    const Text(
      'Os pré-requisitos usam identificadores das disciplinas. O catálogo, os perfis e a estrutura são salvos juntos.',
    ),
    Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => onEditProfile(null),
          icon: const Icon(Icons.add),
          label: const Text('Novo perfil'),
        ),
        OutlinedButton(
          onPressed: onEditRequirements,
          child: const Text('Requisitos gerais'),
        ),
        OutlinedButton(
          onPressed: onEditWhole,
          child: const Text('JSON completo'),
        ),
      ],
    ),
    for (final profile in records(curriculum['profiles']))
      Card(
        child: ListTile(
          title: Text(
            '${profile['name'] ?? profile['id']}${curriculum['activeProfileId'] == profile['id'] ? ' · Padrão' : ''}',
          ),
          subtitle: Text(
            '${profile['id']} · ${profile['totalHours'] ?? '—'}h · ${records(profile['subjects']).length} disciplinas',
          ),
          trailing: Wrap(
            children: [
              IconButton(
                tooltip: 'Padrão',
                onPressed: () => onActiveProfileChanged('${profile['id']}'),
                icon: const Icon(Icons.star_outline),
              ),
              IconButton(
                tooltip: 'Editar perfil',
                onPressed: () => onEditProfile(profile),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Excluir perfil',
                onPressed: () => onDeleteProfile(profile),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    filters,
    for (final node in records(curriculum['treeSubjects']).where(
      (row) =>
          (selectedProfile.isEmpty || row['profile'] == selectedProfile) &&
          (selectedPeriod.isEmpty || '${row['period']}' == selectedPeriod) &&
          '${row['name']} ${row['code']}'.toLowerCase().contains(
            searchController.text.toLowerCase(),
          ),
    ))
      AdminPanel('${node['code'] ?? ''} · ${node['name']}', [
        Text(
          'Período ${node['period'] ?? '—'} · ${node['hours'] ?? '—'}h · ${node['type']}',
        ),
        Text(
          'Pré-requisitos: ${(node['prereqs'] as List? ?? []).map((id) => records(curriculum['treeSubjects']).where((candidate) => candidate['id'] == id).firstOrNull?['name'] ?? id).join(', ')}',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => onEditLinks(node),
            child: const Text('Editar relações e estrutura'),
          ),
        ),
      ]),
  ], action: saveAction);
}
