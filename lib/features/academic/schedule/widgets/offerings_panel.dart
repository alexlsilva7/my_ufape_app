import 'package:flutter/material.dart';

import '../../../../core/models.dart';
import '../../widgets/academic_common.dart';
import '../../widgets/academic_motion.dart';
import '../../widgets/academic_palette.dart';
import 'period_filter.dart';

class ScheduleOfferingsPanel extends StatelessWidget {
  const ScheduleOfferingsPanel({
    super.key,
    required this.profiles,
    required this.periods,
    required this.hasElectives,
    required this.selectedProfile,
    required this.loading,
    required this.emptySource,
    required this.identity,
    required this.duration,
    required this.query,
    required this.selectedPeriod,
    required this.searchController,
    required this.offerings,
    required this.itemBuilder,
    required this.onHelp,
    required this.onProfileChanged,
    required this.onQueryChanged,
    required this.onPeriodChanged,
  });
  final List<String> profiles;
  final List<int> periods;
  final bool hasElectives;
  final String selectedProfile;
  final bool loading;
  final bool emptySource;
  final Object identity;
  final Duration duration;
  final String query;
  final int? selectedPeriod;
  final TextEditingController searchController;
  final List<Discipline> offerings;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback onHelp;
  final ValueChanged<String> onProfileChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int?> onPeriodChanged;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AcademicPalette.of(context).surface,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            children: [
              if (profiles.length > 1) ...[
                AcademicDropdown<String>(
                  value: selectedProfile,
                  items: {
                    'all': 'Todos os perfis',
                    for (final profile in profiles) profile: profile,
                  },
                  label: 'Perfil / matriz',
                  width: double.infinity,
                  onChanged: onProfileChanged,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'PERÍODOS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6,
                        color: AcademicPalette.of(context).muted,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onHelp,
                    icon: Icon(
                      Icons.help_outline,
                      size: 15,
                      color: AcademicPalette.of(context).indigo,
                    ),
                    label: Text(
                      'Como usar',
                      style: TextStyle(
                        fontSize: 11,
                        color: AcademicPalette.of(context).indigo,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ],
              ),
              SchedulePeriodFilter(
                periods: periods,
                hasElectives: hasElectives,
                selectedPeriod: selectedPeriod,
                onChanged: onPeriodChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Pesquisar disciplina ou professor...',
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: AcademicPalette.of(context).muted,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar pesquisa',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            searchController.clear();
                            onQueryChanged('');
                          },
                        ),
                ),
                onChanged: onQueryChanged,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: AcademicPalette.of(context).border),
        Expanded(
          child: AcademicTransition(
            identity: identity,
            duration: duration,
            slide: true,
            child: loading && emptySource
                ? const Center(child: CircularProgressIndicator())
                : offerings.isEmpty
                ? AcademicEmpty(
                    emptySource
                        ? 'Nenhuma oferta disponível para este curso e semestre.'
                        : 'Nenhuma disciplina encontrada com esses filtros.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                    itemCount: offerings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: itemBuilder,
                  ),
          ),
        ),
      ],
    ),
  );
}
