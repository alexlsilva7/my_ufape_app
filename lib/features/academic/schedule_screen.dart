import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../services/files.dart';
import '../../services/widget_image.dart';
import 'academic_common.dart';
import 'academic_motion.dart';
import 'academic_palette.dart';
import 'schedule/badge.dart';
import 'schedule/offering_card.dart';
import 'schedule/export_card.dart';
import 'schedule/week_grid.dart';
import 'schedule/week_layout.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.state});
  final AppState state;
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String _query = '';
  int? _period;
  String _shift = 'auto';
  bool _exporting = false;
  final _search = TextEditingController();
  final _periodScroll = ScrollController();
  AppState get state => widget.state;

  Duration _motion([int milliseconds = 240]) =>
      academicMotionDuration(context, milliseconds, disabled: _exporting);

  @override
  void dispose() {
    _search.dispose();
    _periodScroll.dispose();
    super.dispose();
  }

  void _toggle(Discipline offering) {
    final error = state.toggleDiscipline(offering);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.deepOrange.shade700,
        ),
      );
    }
  }

  Future<void> _export() async {
    if (_exporting || state.schedule.isEmpty) return;
    final selected = List<Discipline>.of(state.schedule);
    final course = state.selectedCourse;
    final semester = state.selectedSemester;
    final date = DateTime.now();
    setState(() => _exporting = true);
    try {
      await precacheImage(
        const AssetImage(ScheduleExportCard.logoAsset),
        context,
      );
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final courseName =
          course?.id == 'bcc' &&
              normalized(course!.name) == 'ciencia da computacao'
          ? 'Bacharelado em Ciência da Computação'
          : course?.name ?? 'Curso';
      final bytes = await renderWidgetPng(
        context,
        ScheduleExportCard(
          courseName: courseName,
          semester: semester,
          selected: selected,
          date: date,
        ),
        width: ScheduleExportCard.logicalWidth,
      );
      await saveBytes(
        'grade-${course?.id ?? 'academica'}-$semester.png',
        bytes,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível exportar a imagem: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  AcademicPalette get _palette => AcademicPalette.of(context);
  Color get _surface => _palette.surface;
  Color get _canvas => _palette.canvas;
  Color get _border => _palette.border;
  Color get _ink => _palette.ink;
  Color get _muted => _palette.muted;
  Color get _indigo => _palette.indigo;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _canvas,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _border),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: _canvas,
              foregroundColor: _ink,
              side: BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Inter'),
          child: ColoredBox(
            color: _canvas,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 1024 &&
                    MediaQuery.textScalerOf(context).scale(14) < 24;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: constraints.maxWidth >= 1280 ? 320 : 280,
                        child: _offerings(),
                      ),
                      VerticalDivider(width: 1, color: _border),
                      Expanded(child: _week()),
                    ],
                  );
                }
                return DefaultTabController(
                  length: 2,
                  animationDuration: _motion(280),
                  child: Column(
                    children: [
                      ColoredBox(
                        color: _surface,
                        child: TabBar(
                          labelColor: _indigo,
                          indicatorColor: _indigo,
                          tabs: [
                            Tab(
                              height: math.max(
                                72,
                                48 +
                                    MediaQuery.textScalerOf(context).scale(14) *
                                        2,
                              ),
                              icon: const Icon(Icons.playlist_add_outlined),
                              text: 'Disciplinas',
                            ),
                            Tab(
                              height: math.max(
                                72,
                                48 +
                                    MediaQuery.textScalerOf(context).scale(14) *
                                        2,
                              ),
                              icon: const Icon(
                                Icons.calendar_view_week_outlined,
                              ),
                              text: 'Minha grade (${state.schedule.length})',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(children: [_offerings(), _week()]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );

  Widget _offerings() {
    final profiles =
        state.offerings
            .map((d) => d.profile)
            .whereType<String>()
            .where((p) => p.isNotEmpty && normalized(p) != 'optativa')
            .toSet()
            .toList()
          ..sort();
    final periods =
        state.offerings
            .map((d) => d.period)
            .whereType<int>()
            .where((p) => p > 0)
            .toSet()
            .toList()
          ..sort();
    final hasElectives = state.offerings.any((d) => d.period == 0);
    final offerings = state.filteredOfferings(
      query: _query,
      period: _query.trim().isEmpty ? _period : null,
      profile: state.selectedProfile,
    );
    return ColoredBox(
      color: _surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              children: [
                if (profiles.length > 1) ...[
                  AcademicDropdown<String>(
                    value: state.selectedProfile,
                    items: {
                      'all': 'Todos os perfis',
                      for (final profile in profiles) profile: profile,
                    },
                    label: 'Perfil / matriz',
                    width: double.infinity,
                    onChanged: state.selectProfile,
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
                          color: _muted,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _help,
                      icon: Icon(Icons.help_outline, size: 15, color: _indigo),
                      label: Text(
                        'Como usar',
                        style: TextStyle(fontSize: 11, color: _indigo),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ],
                ),
                _periodFilter(periods, hasElectives),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar disciplina ou professor...',
                    prefixIcon: Icon(Icons.search, size: 18, color: _muted),
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
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border),
          Expanded(
            child: AcademicTransition(
              identity: (
                state.selectedCourse?.id,
                state.selectedSemester,
                state.selectedProfile,
                _period,
                normalized(_query),
                state.loading,
              ),
              duration: _motion(180),
              slide: true,
              child: state.loading && state.offerings.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : offerings.isEmpty
                  ? AcademicEmpty(
                      state.offerings.isEmpty
                          ? 'Nenhuma oferta disponível para este curso e semestre.'
                          : 'Nenhuma disciplina encontrada com esses filtros.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                      itemCount: offerings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _offeringCard(offerings[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodFilter(List<int> periods, bool hasElectives) => Container(
    decoration: BoxDecoration(
      color: _canvas,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Períodos anteriores',
          onPressed: () => _scrollPeriods(-1),
          icon: Icon(Icons.chevron_left, size: 18, color: _muted),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Scrollbar(
              key: const ValueKey('schedule-period-scrollbar'),
              controller: _periodScroll,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _periodScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    for (final period in <int?>[
                      null,
                      ...periods,
                      if (hasElectives) 0,
                    ])
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: _periodButton(period),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Próximos períodos',
          onPressed: () => _scrollPeriods(1),
          icon: Icon(Icons.chevron_right, size: 18, color: _muted),
        ),
      ],
    ),
  );

  void _scrollPeriods(int direction) {
    if (!_periodScroll.hasClients) return;
    final position = _periodScroll.position;
    final target =
        (position.pixels + direction * position.viewportDimension * .8).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    final duration = _motion(200);
    if (duration == Duration.zero) {
      _periodScroll.jumpTo(target);
    } else {
      _periodScroll.animateTo(
        target,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _periodButton(int? period) => Padding(
    padding: const EdgeInsets.all(4),
    child: TextButton(
      key: ValueKey('schedule-period-$period'),
      onPressed: () => setState(() {
        _period = period;
        _query = '';
        _search.clear();
      }),
      style: TextButton.styleFrom(
        animationDuration: _motion(180),
        minimumSize: const Size(48, 48),
        backgroundColor: _period == period ? _surface : Colors.transparent,
        foregroundColor: _period == period ? _ink : _muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        period == null
            ? 'Todos'
            : period == 0
            ? 'Optativas'
            : '$periodº',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _offeringCard(Discipline offering) => ScheduleOfferingCard(
    key: ValueKey(offering.id),
    offering: offering,
    selected: state.schedule.any((d) => d.id == offering.id),
    completed: state.isCompleted(offering),
    conflict: _conflict(offering),
    disableMotion: _exporting,
    onToggle: () => _toggle(offering),
    onCompleted: () =>
        state.setCompleted(offering, !state.isCompleted(offering)),
    onDetails: () => _details(offering),
  );

  Discipline? _conflict(Discipline offering) {
    for (final existing in state.schedule) {
      if (existing.id == offering.id) continue;
      for (final a in offering.sessions) {
        for (final b in existing.sessions) {
          if (a.day == b.day &&
              a.startMinutes != null &&
              a.endMinutes != null &&
              b.startMinutes != null &&
              b.endMinutes != null &&
              a.startMinutes! < b.endMinutes! &&
              b.startMinutes! < a.endMinutes!) {
            return existing;
          }
        }
      }
    }
    return null;
  }

  Future<void> _details(Discipline offering) async {
    final subject = subjectForOffering(state, offering);
    if (subject != null) {
      await showAcademicDetails(context, state, subject);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(offering.name),
        content: Text(
          '${offering.code ?? ''}\n${offering.professor ?? 'Professor a confirmar'}\n\n${offering.sessions.map((s) => '${scheduleDays[(s.day - 1).clamp(0, 5)]}: ${s.time}').join('\n')}\n\nEmenta não disponível no catálogo deste curso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _week() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: _surface,
          border: Border(bottom: BorderSide(color: _border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Sua Grade',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  AcademicTransition(
                    identity: state.schedule.length,
                    duration: _motion(180),
                    child: ScheduleBadge(
                      '${state.schedule.length} ${state.schedule.length == 1 ? 'disciplina' : 'disciplinas'}',
                      disableMotion: _exporting,
                      foreground: _muted,
                    ),
                  ),
                  SizedBox(
                    width: math.min(390, constraints.maxWidth),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _canvas,
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            for (final entry in const {
                              'auto': 'Automático',
                              'manha': 'Manhã',
                              'tarde': 'Tarde',
                              'noite': 'Noite',
                              'all': 'Todos',
                            }.entries)
                              TextButton(
                                key: ValueKey('schedule-shift-${entry.key}'),
                                onPressed: () =>
                                    setState(() => _shift = entry.key),
                                style: TextButton.styleFrom(
                                  animationDuration: _motion(180),
                                  minimumSize: const Size(48, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  foregroundColor: _shift == entry.key
                                      ? _indigo
                                      : _muted,
                                  backgroundColor: _shift == entry.key
                                      ? _surface
                                      : Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _exporting || state.schedule.isEmpty
                        ? null
                        : _export,
                    icon: _exporting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined, size: 16),
                    label: const Text('Salvar imagem'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _help,
                    icon: const Icon(Icons.help_outline, size: 16),
                    label: const Text('Como usar'),
                    style: OutlinedButton.styleFrom(foregroundColor: _indigo),
                  ),
                  if (state.schedule.isNotEmpty)
                    IconButton(
                      tooltip: 'Limpar grade',
                      onPressed: _clearSchedule,
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gridWidth = math.max(constraints.maxWidth - 40, 900.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: RepaintBoundary(
                  child: ColoredBox(
                    color: _canvas,
                    child: SizedBox(
                      width: gridWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: _surface,
                              border: Border.all(color: _border),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .04),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ScheduleWeekGrid(
                              selected: state.schedule,
                              available: state.offerings,
                              shift: _shift,
                              scope: (
                                state.selectedCourse?.id,
                                state.selectedSemester,
                              ),
                              availableHeight: constraints.maxHeight - 40,
                              onDetails: _details,
                              onToggle: _toggle,
                              onCompleted: (offering) => state.setCompleted(
                                offering,
                                !state.isCompleted(offering),
                              ),
                              disableMotion: _exporting,
                            ),
                          ),
                          ..._unassigned(),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '${state.selectedCourse?.name ?? 'Grade Acadêmica'} • ${state.selectedSemester} • Horários sujeitos a alterações oficiais',
                              style: TextStyle(fontSize: 10, color: _muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Future<void> _clearSchedule() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar a grade?'),
        content: const Text(
          'As disciplinas serão removidas desta grade. Seu progresso na matriz será mantido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (clear == true) state.clearSchedule();
  }

  List<Widget> _unassigned() {
    final items = state.schedule
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
    if (items.isEmpty) return [];
    return [
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
          onTap: () => _details(item),
          trailing: IconButton(
            tooltip: 'Remover disciplina',
            onPressed: () => _toggle(item),
            icon: const Icon(Icons.close),
          ),
        ),
    ];
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Como montar sua grade'),
      content: const SingleChildScrollView(
        child: Text(
          '1. Escolha o curso e o semestre no cabeçalho.\n\n2. Filtre o perfil e o período ou pesquise uma disciplina, código ou professor.\n\n3. Toque em um cartão para adicionar à grade. Horários sobrepostos são sinalizados e impedidos.\n\n4. Use o ícone de conclusão para registrar disciplinas já cursadas. Elas também serão concluídas na matriz.\n\n5. Na aba Minha grade, confira a semana, remova disciplinas com × e use Salvar imagem para exportar sua grade em PNG.\n\nSeu planejamento é salvo automaticamente neste dispositivo.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}
