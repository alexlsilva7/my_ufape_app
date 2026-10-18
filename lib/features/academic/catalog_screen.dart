import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import 'academic_common.dart';
import 'catalog/subject_card.dart';
import 'academic_palette.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.state});
  final AppState state;
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _query = '';
  String _type = 'all';
  int? _period;
  final _search = TextEditingController();

  AcademicPalette get _palette => AcademicPalette.of(context);
  bool get _dark => _palette.dark;
  Color get _border => _palette.strongBorder;
  Color get _muted => _palette.muted;
  Color get _surface => _palette.surface;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) {
      final state = widget.state;
      final catalog = state.catalogSubjects;
      final profiles =
          catalog
              .map((s) => s.profile)
              .whereType<String>()
              .where((p) => p.isNotEmpty && normalized(p) != 'optativa')
              .toSet()
              .toList()
            ..sort();
      final periods =
          catalog.map((s) => s.period).whereType<int>().toSet().toList()
            ..sort();
      final query = normalized(_query);
      final subjects = catalog
          .where(
            (subject) =>
                normalized(
                  '${subject.name} ${subject.code ?? ''} ${subject.profile ?? ''}',
                ).contains(query) &&
                (_period == null || subject.period == _period) &&
                (state.selectedProfile == 'all' ||
                    profiles.length <= 1 ||
                    isCatalogElective(subject) ||
                    subject.profile == state.selectedProfile) &&
                (_type == 'all' ||
                    (_type == 'optativa'
                        ? isCatalogElective(subject)
                        : !isCatalogElective(subject))),
          )
          .toList();
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
                              _filters(profiles, periods, scale),
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
                                    state,
                                    subjects[index],
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

  InputDecoration _inputDecoration({String? hintText}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _border),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: _muted.withValues(alpha: .8), fontSize: 14),
      filled: true,
      fillColor: _surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: const BoxConstraints(minHeight: 44),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
    );
  }

  Widget _select<T>(
    String label,
    T value,
    Map<T, String> items,
    ValueChanged<T> onChanged,
  ) => Semantics(
    label: label,
    child: DropdownButtonFormField<T>(
      key: ValueKey('catalog-$label:$value:${items.keys.join(',')}'),
      initialValue: items.containsKey(value) ? value : items.keys.first,
      isExpanded: true,
      decoration: _inputDecoration(),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: _dark ? const Color(0xffe2e8f0) : const Color(0xff1e293b),
      ),
      icon: const Icon(Icons.expand_more, size: 18),
      dropdownColor: _surface,
      items: [
        for (final item in items.entries)
          DropdownMenuItem(
            value: item.key,
            child: Text(item.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );

  Widget _filters(List<String> profiles, List<int> periods, double scale) =>
      Container(
        key: const ValueKey('catalog-filters'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _dark
              ? const Color(0xff1e293b).withValues(alpha: .5)
              : const Color(0xfff1f5f9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 14),
              decoration:
                  _inputDecoration(hintText: 'Pesquisar por nome ou código...')
                      .copyWith(
                        prefixIcon: Icon(Icons.search, size: 18, color: _muted),
                        prefixIconConstraints: const BoxConstraints(
                          minHeight: 44,
                          minWidth: 40,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar pesquisa',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
            );
            final period = _select<int>('Período', _period ?? -1, {
              -1: 'Todos Períodos',
              for (final p in periods) p: p == 0 ? 'Optativas' : '$pº Período',
            }, (value) => setState(() => _period = value == -1 ? null : value));
            final type = _select<String>('Tipo', _type, const {
              'all': 'Todos Tipos',
              'obrigatoria': 'Obrigatórias',
              'optativa': 'Optativas',
            }, (value) => setState(() => _type = value));
            final wide = constraints.maxWidth >= 700 && scale <= 1.2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide)
                  Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 16),
                      SizedBox(width: 170, child: period),
                      const SizedBox(width: 8),
                      SizedBox(width: 148, child: type),
                    ],
                  )
                else ...[
                  search,
                  const SizedBox(height: 12),
                  if (constraints.maxWidth >= 400 && scale <= 1.2)
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(child: period),
                        Expanded(child: type),
                      ],
                    )
                  else ...[
                    period,
                    const SizedBox(height: 12),
                    type,
                  ],
                ],
                if (profiles.length > 1) ...[
                  const SizedBox(height: 12),
                  _select<String>(
                    'Perfil / matriz',
                    widget.state.selectedProfile,
                    {'all': 'Todos os perfis', for (final p in profiles) p: p},
                    widget.state.selectProfile,
                  ),
                ],
              ],
            );
          },
        ),
      );
}
