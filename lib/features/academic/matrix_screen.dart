import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../services/files.dart';
import 'academic_common.dart';
import 'academic_motion.dart';
import 'academic_palette.dart';
import 'matrix/subject_card.dart';
import 'matrix/prerequisite_painter.dart';
import 'matrix/progress_summary.dart';
import 'matrix/elective_editor.dart';
import 'matrix/node_layer.dart';
import 'matrix/matrix_motion.dart';
import 'matrix/period_navigation.dart';

class MatrixScreen extends StatefulWidget {
  const MatrixScreen({super.key, required this.state});
  final AppState state;
  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen>
    with SingleTickerProviderStateMixin {
  String _query = '', _status = 'all';
  String? _highlight, _paintHighlight;
  bool? _compact;
  final _search = TextEditingController();
  final _transform = TransformationController();
  late final _viewportMotion = AnimationController(vsync: this)
    ..addListener(_advanceViewport);
  Matrix4Tween? _viewportTween;
  Matrix4? _viewportTarget;
  (double, double, double, bool)? _graphGeometry;
  AppState get state => widget.state;

  Duration _motion([int milliseconds = 200]) =>
      academicMotionDuration(context, milliseconds);

  Widget _resize(Widget child) => _motion() == Duration.zero
      ? child
      : AnimatedSize(
          duration: _motion(240),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topLeft,
          child: child,
        );
  @override
  void dispose() {
    _search.dispose();
    _viewportMotion.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      if (state.loading && state.profiles.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state.profiles.isEmpty) {
        return const AcademicEmpty(
          'Matriz curricular não disponível para este curso.',
          icon: Icons.account_tree_outlined,
        );
      }
      final subjects = state.subjects
          .where(
            (subject) =>
                normalized(
                  '${subject.displayName} ${subject.displayCode ?? ''}',
                ).contains(normalized(_query)) &&
                (_status == 'all' ||
                    (_status == 'disponivel'
                        ? state.subjectStatus(subject) == 'pendente' &&
                              state.isUnlocked(subject)
                        : state.subjectStatus(subject) == _status)),
          )
          .toList();
      return LayoutBuilder(
        builder: (context, constraints) {
          final mobile =
              constraints.maxWidth < 700 ||
              MediaQuery.textScalerOf(context).scale(14) > 21;
          final compact = _compact ?? mobile;
          final theme = Theme.of(context);
          final dark = theme.brightness == Brightness.dark;
          final surface = dark ? const Color(0xff0f172a) : Colors.white;
          final border = dark
              ? const Color(0xff334155)
              : const Color(0xffcbd5e1);
          final localTheme = theme.copyWith(
            textTheme: theme.textTheme
                .apply(fontFamily: 'Inter')
                .copyWith(
                  titleMedium: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'Inter',
                    fontSize: 13,
                  ),
                ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: border),
                backgroundColor: surface,
              ),
            ),
          );
          final toolbar = _toolbar(constraints.maxWidth, compact);
          final content = SingleChildScrollView(
            key: const ValueKey('matrix-page-scroll'),
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 24,
              20,
              mobile ? 16 : 24,
              32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mobile) ...[toolbar, const SizedBox(height: 16)],
                if (mobile) ...[
                  _legend(subjects.length),
                  const SizedBox(height: 16),
                ],
                _resize(
                  AcademicTransition(
                    identity: (
                      state.selectedCourse?.id,
                      state.activeProfile?.id,
                      compact,
                      subjects.isEmpty,
                      compact ? subjects.map((s) => s.id).join('|') : null,
                    ),
                    duration: _motion(180),
                    slide: true,
                    child: subjects.isEmpty
                        ? const AcademicEmpty(
                            'Nenhuma disciplina encontrada com esses filtros.',
                          )
                        : compact
                        ? Column(
                            children: [
                              _compactMatrix(subjects),
                              OutlinedButton.icon(
                                onPressed: () => _electiveEditor(),
                                icon: const Icon(Icons.add),
                                label: const Text('Adicionar optativa'),
                              ),
                            ],
                          )
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1920),
                              child: _graph(subjects),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: MatrixProgressSummary(
                      progress: state.progress,
                      profile: state.activeProfile!,
                      courseId: state.selectedCourse?.id,
                      acexHours: state.acexHours,
                      accHours: state.accHours,
                      onAcexChanged: (value) => state.setHours(acex: value),
                      onAccChanged: (value) => state.setHours(acc: value),
                    ),
                  ),
                ),
              ],
            ),
          );
          return DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Inter'),
            child: Theme(
              data: localTheme,
              child: mobile
                  ? content
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xff020617)
                                : const Color(0xfff1f5f9),
                            border: Border(bottom: BorderSide(color: border)),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1280),
                              child: toolbar,
                            ),
                          ),
                        ),
                        Expanded(child: content),
                      ],
                    ),
            ),
          );
        },
      );
    },
  );

  Widget _toolbar(double width, bool compact) {
    final mobile =
        width < 700 || MediaQuery.textScalerOf(context).scale(14) > 21;
    final available = math.min(1280.0, width - (mobile ? 32 : 48));
    final search = SizedBox(
      width: mobile ? available : 300,
      child: TextField(
        controller: _search,
        onChanged: (value) => setState(() {
          _query = value;
          _highlight = null;
        }),
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Pesquisar por nome de disciplina...',
          prefixIcon: const Icon(Icons.search, size: 17),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar pesquisa',
                  icon: const Icon(Icons.close, size: 17),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
      ),
    );
    final filter = AcademicDropdown<String>(
      value: _status,
      items: const {
        'all': 'Todos os estados',
        'pendente': 'Pendentes',
        'cursando': 'Cursando',
        'concluido': 'Concluídas',
        'disponivel': 'Disponíveis',
      },
      onChanged: (value) => setState(() {
        _status = value;
        _highlight = null;
      }),
      label: 'Estado',
      width: mobile ? available : 250,
    );
    final profiles = state.profiles.length <= 3 && !mobile
        ? SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              selectedBackgroundColor: _dark
                  ? const Color(0xff312e81)
                  : const Color(0xffe0e7ff),
              selectedForegroundColor: _dark
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
              for (final profile in state.profiles)
                ButtonSegment(
                  value: profile.id,
                  label: Tooltip(
                    message: profile.name,
                    child: Text(_profileLabel(profile)),
                  ),
                ),
            ],
            selected: {state.activeProfile!.id},
            onSelectionChanged: (values) => _selectProfile(values.first),
          )
        : AcademicDropdown<String>(
            value: state.activeProfile!.id,
            items: {
              for (final profile in state.profiles)
                profile.id: '${profile.id} • ${profile.name}',
            },
            label: 'Perfil curricular',
            width: mobile ? available : 250,
            onChanged: _selectProfile,
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
                Expanded(child: profiles),
              ],
            )
          else ...[
            filter,
            profiles,
          ],
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _compact = !compact),
                  icon: AcademicTransition(
                    identity: compact,
                    duration: _motion(160),
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
                    _help();
                  } else if (action == 'reset') {
                    _resetProgress();
                  } else {
                    _profileAction(action);
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
        profiles,
        OutlinedButton.icon(
          onPressed: _help,
          icon: const Icon(Icons.help_outline, size: 15),
          label: const Text('Como usar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _dark
                ? const Color(0xffc7d2fe)
                : const Color(0xff4f46e5),
            backgroundColor: _dark
                ? const Color(0xff1e1b4b)
                : const Color(0xffeef2ff),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _resetProgress,
          icon: const Icon(Icons.restart_alt, size: 16),
          label: const Text('Limpar progresso'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _dark
                ? const Color(0xfffda4af)
                : const Color(0xffbe123c),
            backgroundColor: _dark
                ? const Color(0xff4c0519)
                : const Color(0xfffff1f2),
            side: BorderSide(
              color: _dark ? const Color(0xff881337) : const Color(0xfffecdd3),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Progresso do perfil',
          icon: const Icon(Icons.more_horiz, size: 18),
          onSelected: _profileAction,
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

  void _selectProfile(String value) {
    _stopViewportMotion();
    _transform.value = Matrix4.identity();
    state.selectProfile(value);
    setState(() {
      _highlight = null;
      _paintHighlight = null;
    });
  }

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color _statusColor(String status) =>
      AcademicPalette.of(context).matrixStatusColor(status);
  IconData _statusIcon(String status) => switch (status) {
    'concluido' => Icons.check_circle_outline,
    'cursando' => Icons.timelapse,
    _ => Icons.circle_outlined,
  };

  Widget _legend(int count) => Wrap(
    spacing: 20,
    runSpacing: 10,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final entry in statusNames.entries)
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Icon(
              _statusIcon(entry.key),
              size: 16,
              color: _statusColor(entry.key),
            ),
            Flexible(
              child: Text(entry.value, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      const Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(Icons.lock_outline, size: 16),
          Flexible(
            child: Text(
              'Pré-requisito pendente',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      AcademicTransition(
        identity: count,
        duration: _motion(160),
        child: Text(
          '$count disciplinas',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _profileAction(String action) async {
    final course = state.selectedCourse?.id ?? 'bcc';
    final profile = state.activeProfile?.id ?? 'matriz';
    try {
      if (action == 'export') {
        await saveJson(
          '${course}_${profile}_progresso.json',
          state.exportProfileProgress(),
        );
        return;
      }
      final text = await importJson();
      if (text == null || !mounted) return;
      if (state.selectedCourse?.id != course ||
          state.activeProfile?.id != profile) {
        _message('O curso ou perfil mudou. Abra a importação novamente.');
        return;
      }
      final data = jsonDecode(text);
      if (data is! Map || data['subjects'] is! List) {
        _message(
          'Arquivo de progresso inválido. Selecione um arquivo exportado pela matriz.',
        );
        return;
      }
      if (data['course'] is! String ||
          data['profileId'] is! String ||
          normalized(data['course']) != normalized(course) ||
          normalized(data['profileId']) != normalized(profile)) {
        _message(
          'Este arquivo não corresponde ao curso $course e perfil $profile abertos.',
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        animationStyle: academicDialogMotion(context),
        builder: (context) => AlertDialog(
          title: const Text('Importar progresso do perfil?'),
          content: Text(
            'O progresso do perfil $profile será substituído pelo arquivo: status, notas, escolhas de optativas e horas de ACEX e ACC.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importar progresso'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (state.selectedCourse?.id != course ||
          state.activeProfile?.id != profile) {
        _message('O curso ou perfil mudou. Abra a importação novamente.');
        return;
      }
      final success = await state.importProfileProgress(text);
      if (success && mounted) setState(() => _highlight = null);
      _message(
        success
            ? 'Progresso do perfil $profile importado.'
            : 'Arquivo de progresso inválido para este curso e perfil.',
      );
    } catch (_) {
      _message(
        action == 'export'
            ? 'Não foi possível exportar o progresso.'
            : 'Não foi possível ler o arquivo de progresso.',
      );
    }
  }

  Future<void> _resetProgress() async {
    final course = state.selectedCourse?.id;
    final profile = state.activeProfile?.id;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: academicDialogMotion(context),
      builder: (context) => AlertDialog(
        title: const Text('Limpar progresso do perfil?'),
        content: Text(
          'Todo o progresso do perfil $profile será apagado: status, notas, escolhas e optativas adicionais, além das horas de ACEX e ACC. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar progresso'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (state.selectedCourse?.id != course ||
        state.activeProfile?.id != profile) {
      _message('O curso ou perfil mudou. Abra a confirmação novamente.');
      return;
    }
    state.resetProfileProgress();
    setState(() => _highlight = null);
    _message('Progresso do perfil $profile limpo.');
  }

  Map<int, List<Subject>> _periods(List<Subject> subjects) {
    final periods = subjects.map((s) => s.period ?? 0).toSet().toList()..sort();
    return {
      for (final period in periods)
        period: subjects.where((s) => (s.period ?? 0) == period).toList(),
    };
  }

  Widget _periodHeading(int period, List<Subject> subjects) {
    final periodSubjects = state.subjects.where(
      (s) => (s.period ?? 0) == period,
    );
    final hours = periodSubjects.fold<double>(
      0,
      (sum, s) => sum + s.displayHours,
    );
    final done = periodSubjects
        .where((s) => state.subjectStatus(s) == 'concluido')
        .fold<double>(0, (sum, s) => sum + s.displayHours);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xff1e293b),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            period == 0 ? 'OPTATIVAS' : '$periodº PERÍODO',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .7,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          AcademicTransition(
            identity: (done, hours),
            duration: _motion(160),
            child: Text(
              '${hoursLabel(done)}h / ${hoursLabel(hours)}h',
              style: const TextStyle(fontSize: 11, color: Color(0xffcbd5e1)),
            ),
          ),
        ],
      ),
    );
  }

  double get _cardHeight =>
      (_comfortableCards ? 144 : 108) +
      math.max(0, MediaQuery.textScalerOf(context).scale(14) / 14 - 1) * 140;

  bool get _comfortableCards =>
      MediaQuery.sizeOf(context).width < 700 ||
      MediaQuery.textScalerOf(context).scale(14) > 21;

  double _subjectHeight(Subject subject) =>
      _cardHeight +
      ((subject.isGenericElective || subject.additionalElective)
          ? (MediaQuery.sizeOf(context).width < 1100 ? 36 : 20)
          : 0) +
      (subject.electiveSelection != null ? 32 : 0);

  Widget _compactMatrix(List<Subject> subjects) => Column(
    children: [
      for (final entry in _periods(subjects).entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: _periodHeading(entry.key, entry.value),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final count = (constraints.maxWidth / 300).floor().clamp(
                    1,
                    5,
                  );
                  final width =
                      (constraints.maxWidth - (count - 1) * 12) / count;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (index, subject) in entry.value.indexed)
                        SizedBox(
                          key: ValueKey('matrix-item-${subject.id}'),
                          width: width,
                          height: _subjectHeight(subject),
                          child: MatrixCardEntrance(
                            order: index,
                            child: _subjectCard(subject),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
    ],
  );

  Widget _graph(List<Subject> subjects) => LayoutBuilder(
    builder: (context, constraints) {
      final periods = _periods(subjects);
      const columnGap = 12.0, rowGap = 12.0;
      final cardWidth = constraints.maxWidth < 1000
          ? 220.0 *
                (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1, 1.5)
          : ((constraints.maxWidth - 16 - (periods.length - 1) * columnGap) /
                    periods.length)
                .clamp(112.0, 240.0);
      final header =
          78.0 +
          math.max(0, MediaQuery.textScalerOf(context).scale(12) - 12) * 3;
      final width = periods.length * (cardWidth + columnGap) - columnGap + 16;
      final nodes = <String, Rect>{};
      var column = 0;
      var height = 0.0;
      for (final list in periods.values) {
        var top = header;
        for (final subject in list) {
          final rect = Rect.fromLTWH(
            8 + column * (cardWidth + columnGap),
            top,
            cardWidth,
            _subjectHeight(subject),
          );
          nodes[subject.id] = rect;
          if (subject.code != null) nodes[subject.code!] = rect;
          top += rect.height + rowGap;
        }
        height = math.max(height, top);
        column++;
      }
      height = math.max(
        height,
        periods.values.last.fold<double>(
              header,
              (top, subject) => top + _subjectHeight(subject) + rowGap,
            ) +
            48,
      );
      height = math.max(height, 280);
      _keepResultsVisible(
        width,
        height,
        constraints.maxWidth,
        resetHorizontal:
            periods.length == 1 && (_query.isNotEmpty || _status != 'all'),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (constraints.maxWidth < 1000) ...[
            MatrixPeriodNavigation(
              periods: periods.keys.toList(),
              stride: cardWidth + columnGap,
              sceneWidth: width,
              viewportWidth: constraints.maxWidth,
              transform: _transform,
              onZoom: _zoom,
              onTransform: _animateViewport,
            ),
            const SizedBox(height: 12),
          ],
          ClipRect(
            child: _resize(
              SizedBox(
                height: height,
                child: Listener(
                  onPointerDown: (_) => _stopViewportMotion(),
                  onPointerPanZoomStart: (_) => _stopViewportMotion(),
                  onPointerSignal: _onGraphPointerSignal,
                  child: InteractiveViewer(
                    transformationController: _transform,
                    scaleFactor: double.infinity,
                    trackpadScrollCausesScale: true,
                    constrained: false,
                    minScale: .35,
                    maxScale: 1.6,
                    boundaryMargin: const EdgeInsets.all(80),
                    alignment: Alignment.topLeft,
                    onInteractionStart: (_) => _stopViewportMotion(),
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(_paintHighlight),
                              tween: Tween(
                                begin: 0,
                                end: _highlight == null ? 0 : 1,
                              ),
                              duration: _motion(220),
                              curve: Curves.easeOutCubic,
                              builder: (context, reveal, _) => CustomPaint(
                                painter: MatrixPrerequisitePainter(
                                  subjects: subjects,
                                  nodes: nodes,
                                  highlight: _paintHighlight,
                                  reveal: reveal,
                                  color: _dark
                                      ? const Color(0xfffb7185)
                                      : const Color(0xfff43f5e),
                                  muted: _dark
                                      ? const Color(0xff2dd4bf)
                                      : const Color(0xff0d9488),
                                ),
                              ),
                            ),
                          ),
                          MatrixNodeLayer(
                            duration: _motion(240),
                            nodes: [
                              for (var c = 0; c < periods.length; c++)
                                MatrixNode(
                                  id: 'period-${periods.keys.elementAt(c)}',
                                  bounds: Rect.fromLTWH(
                                    8 + c * (cardWidth + columnGap),
                                    8,
                                    cardWidth,
                                    header - 16,
                                  ),
                                  child: _periodHeading(
                                    periods.keys.elementAt(c),
                                    periods.values.elementAt(c),
                                  ),
                                ),
                              for (final subject in subjects)
                                MatrixNode(
                                  id: subject.id,
                                  bounds: nodes[subject.id]!,
                                  child: MouseRegion(
                                    onEnter: (_) => setState(() {
                                      _highlight = subject.id;
                                      _paintHighlight = subject.id;
                                    }),
                                    onExit: (_) {
                                      if (_highlight == subject.id) {
                                        setState(() => _highlight = null);
                                      }
                                    },
                                    child: _subjectCard(subject),
                                  ),
                                ),
                              if (_query.isEmpty && _status == 'all')
                                MatrixNode(
                                  id: 'add-elective',
                                  bounds: Rect.fromLTWH(
                                    8 +
                                        (periods.length - 1) *
                                            (cardWidth + columnGap),
                                    periods.values.last.fold<double>(
                                      header,
                                      (top, subject) =>
                                          top +
                                          _subjectHeight(subject) +
                                          rowGap,
                                    ),
                                    cardWidth,
                                    48,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: () => _electiveEditor(),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Adicionar optativa'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (constraints.maxWidth >= 1000)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Diminuir zoom',
                    onPressed: () => _zoom(.85),
                    icon: const Icon(Icons.zoom_out, size: 17),
                  ),
                  IconButton(
                    tooltip: 'Aumentar zoom',
                    onPressed: () => _zoom(1.15),
                    icon: const Icon(Icons.zoom_in, size: 17),
                  ),
                  IconButton(
                    tooltip: 'Restaurar posição',
                    onPressed: () => _animateViewport(Matrix4.identity()),
                    icon: const Icon(
                      Icons.center_focus_strong_outlined,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );

  void _keepResultsVisible(
    double width,
    double height,
    double viewportWidth, {
    bool resetHorizontal = false,
  }) {
    final geometry = (width, height, viewportWidth, resetHorizontal);
    if (_graphGeometry == geometry) return;
    _graphGeometry = geometry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _graphGeometry != geometry) return;
      final matrix = _transform.value;
      final scale = matrix.getMaxScaleOnAxis();
      final x = resetHorizontal
          ? 0.0
          : matrix
                .entry(0, 3)
                .clamp(-math.max(0.0, width * scale - viewportWidth), 0.0);
      final y = matrix
          .entry(1, 3)
          .clamp(-math.max(0.0, height * scale - height), 0.0);
      if (x == matrix.entry(0, 3) && y == matrix.entry(1, 3)) return;
      _animateViewport(
        matrix.clone()
          ..setEntry(0, 3, x)
          ..setEntry(1, 3, y),
      );
    });
  }

  void _onGraphPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !HardwareKeyboard.instance.isControlPressed ||
        event.scrollDelta.dy == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _stopViewportMotion();
      final scale = _transform.value.getMaxScaleOnAxis();
      final next = (scale * math.exp(-event.scrollDelta.dy / 200)).clamp(
        .35,
        1.6,
      );
      final factor = next / scale;
      final focal = event.localPosition;
      // Pre-multiply in viewport coordinates to keep the cursor over the same
      // point in the graph while zooming, including after panning.
      _transform.value = Matrix4.identity()
        ..translateByDouble(focal.dx, focal.dy, 0, 1)
        ..scaleByDouble(factor, factor, factor, 1)
        ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
        ..multiply(_transform.value);
    });
  }

  void _zoom(double factor) {
    final matrix = (_viewportTarget ?? _transform.value).clone();
    final scale = matrix.getMaxScaleOnAxis();
    final next = (scale * factor).clamp(.35, 1.6);
    matrix.scaleByDouble(next / scale, next / scale, next / scale, 1);
    _animateViewport(matrix);
  }

  void _animateViewport(Matrix4 target) {
    _viewportTween = Matrix4Tween(begin: _transform.value.clone(), end: target);
    _viewportTarget = target;
    final duration = _motion(240);
    if (duration == Duration.zero) {
      _stopViewportMotion();
      _transform.value = target;
      return;
    }
    _viewportMotion.duration = duration;
    _viewportMotion.forward(from: 0);
  }

  void _advanceViewport() {
    final tween = _viewportTween;
    if (tween == null) return;
    _transform.value = tween.transform(
      Curves.easeOutCubic.transform(_viewportMotion.value),
    );
    if (_viewportMotion.isCompleted) _viewportTarget = null;
  }

  void _stopViewportMotion() {
    _viewportMotion.stop();
    _viewportTarget = null;
    _viewportTween = null;
  }

  Widget _subjectCard(Subject subject) => MatrixSubjectCard(
    comfortable: _comfortableCards,
    subject: subject,
    status: state.subjectStatus(subject),
    blocked:
        state.subjectStatus(subject) == 'pendente' &&
        !state.isUnlocked(subject),
    highlightedId: _highlight,
    highlightedSubject: state.subjects
        .where((s) => s.id == _highlight)
        .firstOrNull,
    onCycleStatus: () {
      const sequence = ['pendente', 'cursando', 'concluido'];
      final status = state.subjectStatus(subject);
      state.setSubjectStatus(
        subject,
        sequence[(sequence.indexOf(status) + 1) % sequence.length],
      );
    },
    onDetails: () =>
        showAcademicDetails(context, state, subject, editable: true),
    onEditElective: () => _electiveEditor(subject),
    onStatusChanged: (status) => state.setSubjectStatus(subject, status),
  );

  Future<void> _electiveEditor([Subject? slot]) =>
      showMatrixElectiveEditor(context, state, slot);

  void _help() => showDialog<void>(
    context: context,
    animationStyle: academicDialogMotion(context),
    builder: (context) => AlertDialog(
      title: const Text('Sua matriz, seu progresso'),
      content: const SingleChildScrollView(
        child: Text(
          '1. Selecione o perfil curricular que corresponde ao seu ingresso. O progresso e as horas são salvos por curso e perfil.\n\n2. Toque no cartão para alternar entre Pendente, Cursando e Concluída. Use o ícone no canto ou mantenha pressionado para abrir os detalhes, informar a nota e consultar a ementa. No desktop e na Web, o botão direito abre opções de detalhes, status e optativas.\n\n3. As linhas conectam pré-requisitos. Cadeados sinalizam requisitos ainda pendentes. Arraste e amplie a matriz ou use a lista compacta.\n\n4. Defina as optativas a partir do catálogo ou informe nome e carga horária. Você também pode adicionar uma optativa extra.\n\n5. Registre suas horas de extensão (ACEX) e atividades complementares (ACC). O progresso respeita os requisitos do perfil.\n\n6. Exporte ou importe o progresso deste perfil no menu ⋮. Para transferir todos os dados do aplicativo, use o backup geral nas Configurações.\n\n7. Use Limpar progresso para reiniciar os status, notas, optativas e horas do perfil aberto.',
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
