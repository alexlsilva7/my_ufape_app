import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models.dart';
import '../academic_common.dart';
import '../academic_motion.dart';
import '../academic_palette.dart';

class MatrixProgressSummary extends StatelessWidget {
  const MatrixProgressSummary({
    super.key,
    required this.progress,
    required this.profile,
    required this.courseId,
    required this.acexHours,
    required this.accHours,
    required this.onAcexChanged,
    required this.onAccChanged,
  });
  final MatrixProgress progress;
  final CurriculumProfile profile;
  final String? courseId;
  final double acexHours, accHours;
  final ValueChanged<double> onAcexChanged, onAccChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 16,
    children: [
      Row(
        spacing: 8,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const Expanded(
            child: Text(
              'RESUMO DE REQUISITOS E CARGA HORÁRIA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
          ),
        ],
      ),
      _extraHours(context),
      _completedSummary(context),
    ],
  );
  Widget _progressCard(BuildContext context, MatrixProgress progress) => Card(
    margin: EdgeInsets.zero,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 168),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CARGA HORÁRIA TOTAL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AcademicPalette.of(context)
                          .matrixStatusColor('pendente'),
                    ),
                  ),
                ),
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            AcademicTransition(
              identity: (progress.doneHours, progress.totalHours),
              duration: academicMotionDuration(context, 160),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${hoursLabel(progress.doneHours)}h',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' / ${hoursLabel(progress.totalHours)}h',
                      style: TextStyle(
                        fontSize: 13,
                        color: AcademicPalette.of(context)
                            .matrixStatusColor('pendente'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text('Concluído', style: TextStyle(fontSize: 12)),
                ),
                AcademicTransition(
                  identity: progress.percentage,
                  duration: academicMotionDuration(context, 160),
                  child: Text(
                    '${progress.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              key: ValueKey(('matrix-progress', courseId, profile.id)),
              tween: Tween(
                begin: progress.percentage / 100,
                end: progress.percentage / 100,
              ),
              duration: academicMotionDuration(context, 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _extraHours(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 1000
            ? (constraints.maxWidth - 32) / 3
            : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: width, child: _progressCard(context, progress)),
            SizedBox(
              width: width,
              child: _hoursCard(
                context,
                'ACEX • Atividades de extensão',
                acexHours,
                profile.acexHours,
                onAcexChanged,
              ),
            ),
            SizedBox(
              width: width,
              child: _hoursCard(
                context,
                'ACC • Atividades complementares',
                accHours,
                profile.accHours,
                onAccChanged,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _hoursCard(
    BuildContext context,
    String title,
    double value,
    double target,
    ValueChanged<double> onChanged,
  ) => Card(
    margin: EdgeInsets.zero,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 168),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    title.startsWith('ACEX')
                        ? 'HORAS ACEX (EXTENSÃO)'
                        : 'HORAS ACC (COMP.)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AcademicPalette.of(context)
                          .matrixStatusColor('pendente'),
                    ),
                  ),
                ),
                Text(
                  'Meta: ${hoursLabel(target)}h',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (target <= 0)
              Text(
                (profile.raw[title.startsWith('ACEX')
                                ? 'acexHours'
                                : 'accHours'] ??
                            asMap(profile.raw['requisitos'])[title.startsWith(
                                  'ACEX',
                                )
                                ? 'acex_extensao'
                                : 'acc_complementar']) ==
                        null
                    ? 'Carga não informada no documento.'
                    : 'Não exigido neste perfil curricular.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AcademicPalette.of(context)
                      .matrixStatusColor('pendente'),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: value.clamp(0, target),
                      max: target,
                      onChanged: onChanged,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: _MatrixHoursInput(
                      key: ValueKey('$title:$courseId:${profile.id}'),
                      fieldKey: ValueKey(
                        title.startsWith('ACEX')
                            ? 'matrix-hours-acex'
                            : 'matrix-hours-acc',
                      ),
                      value: value,
                      onChanged: onChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text('Restantes:', style: TextStyle(fontSize: 12)),
                  ),
                  AcademicTransition(
                    identity: (target, value),
                    duration: academicMotionDuration(context, 160),
                    child: Text(
                      '${hoursLabel(math.max(0, target - value))}h',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _completedSummary(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth > 720
          ? (constraints.maxWidth - 12) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: _requirement(
              context,
              'Horas obrigatórias concluídas',
              progress.mandatoryHours,
              profile.mandatoryHours,
            ),
          ),
          SizedBox(
            width: width,
            child: _requirement(
              context,
              'Horas optativas concluídas',
              progress.optativeHours,
              profile.optativeHours,
            ),
          ),
        ],
      );
    },
  );

  Widget _requirement(
    BuildContext context,
    String label,
    double done,
    double total,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      spacing: 12,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AcademicPalette.of(context).matrixStatusColor('pendente'),
            ),
          ),
        ),
        AcademicTransition(
          identity: (done, total),
          duration: academicMotionDuration(context, 160),
          child: Text(
            '${hoursLabel(done)}h / ${hoursLabel(total)}h',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MatrixHoursInput extends StatefulWidget {
  const _MatrixHoursInput({
    super.key,
    required this.fieldKey,
    required this.value,
    required this.onChanged,
  });
  final Key fieldKey;
  final double value;
  final ValueChanged<double> onChanged;
  @override
  State<_MatrixHoursInput> createState() => _MatrixHoursInputState();
}

class _MatrixHoursInputState extends State<_MatrixHoursInput> {
  late final _controller = TextEditingController(
    text: hoursLabel(widget.value),
  );
  final _focus = FocusNode();
  @override
  void didUpdateWidget(covariant _MatrixHoursInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      _controller.text = hoursLabel(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: widget.fieldKey,
    controller: _controller,
    focusNode: _focus,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 12),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      suffixText: 'h',
    ),
    onTapOutside: (_) => _focus.unfocus(),
    onChanged: (text) {
      final parsed = double.tryParse(text.replaceAll(',', '.'));
      if (parsed != null && parsed.isFinite && parsed >= 0) {
        widget.onChanged(parsed);
      }
    },
  );
}
