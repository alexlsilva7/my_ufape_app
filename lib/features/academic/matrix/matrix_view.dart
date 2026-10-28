import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/exceptions/persistence_exception.dart';
import '../../../core/models.dart';
import 'matrix_view_model.dart';
import '../../../services/files.dart';
import '../widgets/academic_common.dart';
import '../widgets/academic_motion.dart';
import 'widgets/subject_card.dart';
import 'widgets/matrix_hover_builder.dart';
import 'widgets/matrix_graph.dart';
import 'widgets/matrix_compact_list.dart';
import 'widgets/matrix_toolbar.dart';
import 'widgets/matrix_legend.dart';
import 'widgets/progress_summary.dart';
import 'widgets/elective_editor.dart';

class MatrixView extends StatefulWidget {
  const MatrixView({super.key, required this.viewModel});
  final MatrixViewModel viewModel;
  @override
  State<MatrixView> createState() => _MatrixViewState();
}

class _MatrixViewState extends State<MatrixView>
    with SingleTickerProviderStateMixin {
  String _query = '', _status = 'all';
  final _hover = ValueNotifier<Subject?>(null);
  set _highlight(String? id) => _hover.value = id == null
      ? null
      : state.subjects.where((subject) => subject.id == id).firstOrNull;
  bool? _compact;
  final _search = TextEditingController();
  final _transform = TransformationController();
  late final _viewportMotion = AnimationController(vsync: this)
    ..addListener(_advanceViewport);
  Matrix4Tween? _viewportTween;
  Matrix4? _viewportTarget;
  (double, double, double, bool)? _graphGeometry;
  MatrixViewModel get state => widget.viewModel;

  Duration _motion([int milliseconds = 200]) =>
      academicMotionDuration(context, milliseconds);

  @override
  void dispose() {
    _hover.dispose();
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
          final toolbar = MatrixToolbar(
            width: constraints.maxWidth,
            compact: compact,
            query: _query,
            status: _status,
            searchController: _search,
            profiles: state.profiles,
            activeProfileId: state.activeProfile!.id,
            onQueryChanged: (value) => setState(() {
              _query = value;
              _highlight = null;
            }),
            onStatusChanged: (value) => setState(() {
              _status = value;
              _highlight = null;
            }),
            onSelectProfile: _selectProfile,
            onToggleCompact: () => setState(() => _compact = !compact),
            onHelp: _help,
            onReset: _resetProgress,
            onProfileAction: _profileAction,
          );
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
                  MatrixLegend(count: subjects.length),
                  const SizedBox(height: 16),
                ],
                AcademicResize(
                  child: AcademicTransition(
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
                              MatrixCompactList(
                                periods: _periods(subjects),
                                headingBuilder: _periodHeading,
                                cardBuilder: _subjectCard,
                                subjectHeight: _subjectHeight,
                              ),
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
                              child: MatrixGraph(
                                subjects: subjects,
                                periods: _periods(subjects),
                                subjectHeight: _subjectHeight,
                                transform: _transform,
                                onZoom: _zoom,
                                onTransform: _animateViewport,
                                onStopMotion: _stopViewportMotion,
                                onPointerSignal: _onGraphPointerSignal,
                                highlight: _hover,
                                // Crossing cards emits exit before enter. Keep
                                // the next hover from briefly clearing all cards.
                                onHoverExit: (subject) => Future.microtask(() {
                                  if (mounted && _hover.value?.id == subject.id) {
                                    _hover.value = null;
                                  }
                                }),
                                headingBuilder: _periodHeading,
                                cardBuilder: _subjectCard,
                                onAddElective: () => _electiveEditor(),
                                filtering:
                                    _query.isNotEmpty || _status != 'all',
                                onGeometry: (width, height, viewport, reset) =>
                                    _keepResultsVisible(
                                      width,
                                      height,
                                      viewport,
                                      resetHorizontal: reset,
                                    ),
                              ),
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

  void _selectProfile(String value) {
    _stopViewportMotion();
    _transform.value = Matrix4.identity();
    state.selectProfile(value);
    setState(() {
      _highlight = null;
    });
  }

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
    } on PersistenceException catch (error) {
      _message(error.message);
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
    try {
      await state.resetProfileProgress();
      if (!mounted) return;
      setState(() => _highlight = null);
      _message('Progresso do perfil $profile limpo.');
    } on PersistenceException catch (error) {
      if (mounted) _message(error.message);
    }
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

  Widget _subjectCard(Subject subject) {
    final status = state.subjectStatus(subject);
    final blocked = status == 'pendente' && !state.isUnlocked(subject);
    return MatrixHoverBuilder(
      subject: subject,
      highlight: _hover,
      builder: (context, selected) => RepaintBoundary(
        child: MatrixSubjectCard(
          comfortable: _comfortableCards,
          subject: subject,
          status: status,
          blocked: blocked,
          highlightedId: selected?.id,
          highlightedSubject: selected,
          onCycleStatus: () {
            const sequence = ['pendente', 'cursando', 'concluido'];
            final status = state.subjectStatus(subject);
            state.setSubjectStatus(
              subject,
              sequence[(sequence.indexOf(status) + 1) % sequence.length],
            );
          },
          onDetails: () => showAcademicDetails(
            context,
            subject,
            listenable: state,
            subjects: state.subjects,
            courseDetails: state.courseDetails,
            progress: state,
            editable: true,
          ),
          onEditElective: () => _electiveEditor(subject),
          onStatusChanged: (status) => state.setSubjectStatus(subject, status),
        ),
      ),
    );
  }

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
