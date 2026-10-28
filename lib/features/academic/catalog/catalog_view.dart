import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../widgets/academic_common.dart';
import 'catalog_view_model.dart';
import 'widgets/subject_card.dart';
import 'widgets/catalog_filters.dart';
import '../widgets/academic_palette.dart';

class CatalogView extends StatefulWidget {
  const CatalogView({super.key, required this.viewModel});
  final CatalogViewModel viewModel;
  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  String _query = '';
  String _type = 'all';
  int? _period;
  final _search = TextEditingController();

  AcademicPalette get _palette => AcademicPalette.of(context);
  Color get _muted => _palette.muted;
  Color get _surface => _palette.surface;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final state = widget.viewModel;
      final catalog = state.catalogSubjects;
      final profiles = state.profiles;
      final periods = state.periods;
      final query = normalized(_query);
      final subjects = state.filteredSubjects(
        query: _query,
        type: _type,
        period: _period,
      );
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final extraScale = (scale - 1).clamp(0.0, 4.0);
      final filtering = query.isNotEmpty || _period != null || _type != 'all';
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1280),
          color: _surface,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter = constraints.maxWidth < 600 ? 16.0 : 32.0;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 896 + gutter * 2),
                  child: CustomScrollView(
                    key: const PageStorageKey('catalog-scroll'),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(gutter, 32, gutter, 32),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CatalogFilters(
                                profiles: profiles,
                                periods: periods,
                                scale: scale,
                                query: _query,
                                typeValue: _type,
                                selectedPeriod: _period,
                                selectedProfile: state.selectedProfile,
                                searchController: _search,
                                onQueryChanged: (value) =>
                                    setState(() => _query = value),
                                onTypeChanged: (value) =>
                                    setState(() => _type = value),
                                onPeriodChanged: (value) =>
                                    setState(() => _period = value),
                                onProfileChanged: state.selectProfile,
                              ),
                              if (filtering) ...[
                                const SizedBox(height: 16),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    '${subjects.length} ${subjects.length == 1 ? 'disciplina encontrada' : 'disciplinas encontradas'}',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (state.loading && catalog.isEmpty)
                        const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (subjects.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: AcademicEmpty(
                            catalog.isEmpty
                                ? 'Nenhuma disciplina disponível para este curso.'
                                : 'Nenhuma disciplina encontrada com esses filtros.',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) => SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        constraints.crossAxisExtent >= 640 &&
                                            scale <= 1.5
                                        ? 2
                                        : 1,
                                    mainAxisExtent: 186 + extraScale * 155,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => CatalogSubjectCard(
                                  subject: subjects[index],
                                  onDetails: () => showAcademicDetails(
                                    context,
                                    subjects[index],
                                    listenable: state,
                                    subjects: state.catalogSubjects,
                                    courseDetails: state.courseDetails,
                                  ),
                                ),
                                childCount: subjects.length,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
