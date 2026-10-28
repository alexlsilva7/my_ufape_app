import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../../../../core/models.dart';
import '../../widgets/academic_common.dart';
import '../../widgets/academic_motion.dart';

class MatrixToolbar extends StatelessWidget {
  const MatrixToolbar({
    super.key,
    required this.width,
    required this.compact,
    required this.query,
    required this.status,
    required this.searchController,
    required this.profiles,
    required this.activeProfileId,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onSelectProfile,
    required this.onToggleCompact,
    required this.onHelp,
    required this.onReset,
    required this.onProfileAction,
  });
  final double width;
  final bool compact;
  final String query;
  final String status;
  final TextEditingController searchController;
  final List<CurriculumProfile> profiles;
  final String activeProfileId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onToggleCompact;
  final VoidCallback onHelp;
  final VoidCallback onReset;
  final ValueChanged<String> onProfileAction;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mobile =
        width < 700 || MediaQuery.textScalerOf(context).scale(14) > 21;
    final available = math.min(1280.0, width - (mobile ? 32 : 48));
    final search = SizedBox(
      width: mobile ? available : 300,
      child: TextField(
        controller: searchController,
        onChanged: onQueryChanged,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Pesquisar por nome de disciplina...',
          prefixIcon: const Icon(Icons.search, size: 17),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar pesquisa',
                  icon: const Icon(Icons.close, size: 17),
                  onPressed: () {
                    searchController.clear();
                    onQueryChanged('');
                  },
                ),
        ),
      ),
    );
    final filter = AcademicDropdown<String>(
      value: status,
      items: const {
        'all': 'Todos os estados',
        'pendente': 'Pendentes',
        'cursando': 'Cursando',
        'concluido': 'Concluídas',
        'disponivel': 'Disponíveis',
      },
      onChanged: onStatusChanged,
      label: 'Estado',
      width: mobile ? available : 250,
    );
    final profileSelector = profiles.length <= 3 && !mobile
        ? SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              selectedBackgroundColor: dark
                  ? const Color(0xff312e81)
                  : const Color(0xffe0e7ff),
              selectedForegroundColor: dark
                  ? const Color(0xffc7d2fe)
                  : const Color(0xff4338ca),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            segments: [
              for (final profile in profiles)
                ButtonSegment(
                  value: profile.id,
                  label: Tooltip(
                    message: profile.name,
                    child: Text(_profileLabel(profile)),
                  ),
                ),
            ],
            selected: {activeProfileId},
            onSelectionChanged: (values) => onSelectProfile(values.first),
          )
        : AcademicDropdown<String>(
            value: activeProfileId,
            items: {
              for (final profile in profiles)
                profile.id: '${profile.id} • ${profile.name}',
            },
            label: 'Perfil curricular',
            width: mobile ? available : 250,
            onChanged: onSelectProfile,
          );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          search,
          if (available >= 480 &&
              MediaQuery.textScalerOf(context).scale(14) < 20)
            Row(
              spacing: 10,
              children: [
                Expanded(child: filter),
                Expanded(child: profileSelector),
              ],
            )
          else ...[
            filter,
            profileSelector,
          ],
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggleCompact,
                  icon: AcademicTransition(
                    identity: compact,
                    duration: academicMotionDuration(context, 160),
                    child: Icon(
                      compact
                          ? Icons.grid_view_outlined
                          : Icons.view_list_outlined,
                      size: 18,
                    ),
                  ),
                  label: Text(
                    compact ? 'Ver matriz ampla' : 'Ver lista compacta',
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Ações da matriz',
                icon: const Icon(Icons.more_horiz),
                onSelected: (action) {
                  if (action == 'help') {
                    onHelp();
                  } else if (action == 'reset') {
                    onReset();
                  } else {
                    onProfileAction(action);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'help', child: Text('Como usar')),
                  PopupMenuItem(
                    value: 'export',
                    child: Text('Exportar progresso do perfil'),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: Text('Importar progresso do perfil'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'reset',
                    child: Text('Limpar progresso'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }
    final actions = Wrap(
      spacing: 8,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        profileSelector,
        OutlinedButton.icon(
          onPressed: onHelp,
          icon: const Icon(Icons.help_outline, size: 15),
          label: const Text('Como usar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: dark
                ? const Color(0xffc7d2fe)
                : const Color(0xff4f46e5),
            backgroundColor: dark
                ? const Color(0xff1e1b4b)
                : const Color(0xffeef2ff),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt, size: 16),
          label: const Text('Limpar progresso'),
          style: OutlinedButton.styleFrom(
            foregroundColor: dark
                ? const Color(0xfffda4af)
                : const Color(0xffbe123c),
            backgroundColor: dark
                ? const Color(0xff4c0519)
                : const Color(0xfffff1f2),
            side: BorderSide(
              color: dark ? const Color(0xff881337) : const Color(0xfffecdd3),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Progresso do perfil',
          icon: const Icon(Icons.more_horiz, size: 18),
          onSelected: onProfileAction,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'export',
              child: Text('Exportar progresso do perfil'),
            ),
            PopupMenuItem(
              value: 'import',
              child: Text('Importar progresso do perfil'),
            ),
          ],
        ),
      ],
    );
    if (!mobile && available >= 1180) {
      return Row(
        children: [
          search,
          const SizedBox(width: 10),
          filter,
          const Spacer(),
          actions,
        ],
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [search, filter, actions],
    );
  }

  String _profileLabel(CurriculumProfile profile) {
    final name = normalized(profile.name);
    if (name.contains('nova')) return 'Grade Nova';
    if (name.contains('antiga')) return 'Grade Antiga';
    return profile.id;
  }
}
