import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/exceptions/persistence_exception.dart';
import '../../../core/models.dart';
import 'schedule_view_model.dart';
import '../../../services/files.dart';
import '../../../services/widget_image.dart';
import '../widgets/academic_common.dart';
import '../widgets/academic_motion.dart';
import '../widgets/academic_palette.dart';
import 'widgets/offerings_panel.dart';
import 'widgets/offering_card.dart';
import 'widgets/export_card.dart';
import 'widgets/week_panel.dart';
import 'widgets/week_layout.dart';

class ScheduleView extends StatefulWidget {
  const ScheduleView({super.key, required this.viewModel});
  final ScheduleViewModel viewModel;
  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  String _query = '';
  int? _period;
  String _shift = 'auto';
  bool _exporting = false;
  final _search = TextEditingController();
  ScheduleViewModel get state => widget.viewModel;

  Duration _motion([int milliseconds = 240]) =>
      academicMotionDuration(context, milliseconds, disabled: _exporting);

  @override
  void dispose() {
    _search.dispose();
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
  Color get _indigo => _palette.indigo;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final offerings = state.filteredOfferings(
        query: _query,
        period: _query.trim().isEmpty ? _period : null,
        profile: state.selectedProfile,
      );
      final offeringsPanel = ScheduleOfferingsPanel(
        profiles: state.offeringProfiles,
        periods: state.offeringPeriods,
        hasElectives: state.hasElectives,
        selectedProfile: state.selectedProfile,
        loading: state.loading,
        emptySource: state.offerings.isEmpty,
        identity: (
          state.selectedCourse?.id,
          state.selectedSemester,
          state.selectedProfile,
          _period,
          normalized(_query),
          state.loading,
        ),
        duration: _motion(180),
        query: _query,
        selectedPeriod: _period,
        searchController: _search,
        offerings: offerings,
        itemBuilder: (context, index) => _offeringCard(offerings[index]),
        onHelp: _help,
        onProfileChanged: state.selectProfile,
        onQueryChanged: (value) => setState(() => _query = value),
        onPeriodChanged: (value) => setState(() {
          _period = value;
          _query = '';
          _search.clear();
        }),
      );
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
                        child: offeringsPanel,
                      ),
                      VerticalDivider(width: 1, color: _border),
                      Expanded(
                        child: ScheduleWeekPanel(
                          courseName:
                              state.selectedCourse?.name ?? 'Grade Acadêmica',
                          semester: state.selectedSemester,
                          selected: state.schedule,
                          available: state.offerings,
                          scope: (
                            state.selectedCourse?.id,
                            state.selectedSemester,
                          ),
                          shift: _shift,
                          exporting: _exporting,
                          onShiftChanged: (value) =>
                              setState(() => _shift = value),
                          onExport: _export,
                          onHelp: _help,
                          onClear: _clearSchedule,
                          onDetails: _details,
                          onToggle: _toggle,
                          onCompleted: (offering) => state.setCompleted(
                            offering,
                            !state.isCompleted(offering),
                          ),
                        ),
                      ),
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
                        child: TabBarView(
                          children: [
                            offeringsPanel,
                            ScheduleWeekPanel(
                              courseName:
                                  state.selectedCourse?.name ??
                                  'Grade Acadêmica',
                              semester: state.selectedSemester,
                              selected: state.schedule,
                              available: state.offerings,
                              scope: (
                                state.selectedCourse?.id,
                                state.selectedSemester,
                              ),
                              shift: _shift,
                              exporting: _exporting,
                              onShiftChanged: (value) =>
                                  setState(() => _shift = value),
                              onExport: _export,
                              onHelp: _help,
                              onClear: _clearSchedule,
                              onDetails: _details,
                              onToggle: _toggle,
                              onCompleted: (offering) => state.setCompleted(
                                offering,
                                !state.isCompleted(offering),
                              ),
                            ),
                          ],
                        ),
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

  Discipline? _conflict(Discipline offering) => state.conflictWith(offering);

  Future<void> _details(Discipline offering) async {
    final subject = subjectForOffering(state.catalogSubjects, offering);
    if (subject != null) {
      await showAcademicDetails(
        context,
        subject,
        listenable: state,
        subjects: state.detailSubjects,
        courseDetails: state.courseDetails,
      );
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
    if (clear == true) {
      try {
        await state.clearSchedule();
        await state.confirmPersistence();
      } on PersistenceException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    }
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
