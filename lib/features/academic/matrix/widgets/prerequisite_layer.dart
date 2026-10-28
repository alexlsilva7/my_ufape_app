import 'package:flutter/material.dart';

import '../../../../core/models.dart';
import '../../widgets/academic_motion.dart';
import 'prerequisite_painter.dart';

class MatrixPrerequisiteLayer extends StatefulWidget {
  const MatrixPrerequisiteLayer({
    super.key,
    required this.subjects,
    required this.nodes,
    required this.highlight,
  });
  final List<Subject> subjects;
  final Map<String, Rect> nodes;
  final ValueNotifier<Subject?> highlight;
  @override
  State<MatrixPrerequisiteLayer> createState() =>
      _MatrixPrerequisiteLayerState();
}

class _MatrixPrerequisiteLayerState extends State<MatrixPrerequisiteLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _reveal;
  String? _lastHighlight;
  Duration _duration = const Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _lastHighlight = widget.highlight.value?.id;
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: _lastHighlight == null ? 0 : 1,
    );
    _reveal = _controller.drive(CurveTween(curve: Curves.easeOutCubic));
    widget.highlight.addListener(_highlightChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _duration = academicMotionDuration(context, 220);
    _controller.duration = _duration;
    if (_duration == Duration.zero) {
      _controller.value = widget.highlight.value == null ? 0 : 1;
    }
  }

  @override
  void didUpdateWidget(MatrixPrerequisiteLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight != widget.highlight) {
      oldWidget.highlight.removeListener(_highlightChanged);
      widget.highlight.addListener(_highlightChanged);
      _highlightChanged();
    }
  }

  void _highlightChanged() {
    final selected = widget.highlight.value;
    final changed = selected != null && _lastHighlight != selected.id;
    if (changed) setState(() => _lastHighlight = selected.id);
    if (_duration == Duration.zero) {
      _controller.value = selected == null ? 0 : 1;
    } else if (selected == null) {
      _controller.reverse();
    } else {
      _controller.forward(from: changed ? 0 : null);
    }
  }

  @override
  void dispose() {
    widget.highlight.removeListener(_highlightChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: CustomPaint(
        painter: MatrixPrerequisitePainter(
          subjects: widget.subjects,
          nodes: widget.nodes,
          highlight: _lastHighlight,
          reveal: _reveal,
          color: dark ? const Color(0xfffb7185) : const Color(0xfff43f5e),
          muted: dark ? const Color(0xff2dd4bf) : const Color(0xff0d9488),
        ),
      ),
    );
  }
}
