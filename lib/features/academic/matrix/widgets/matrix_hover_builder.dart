import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/models.dart';

/// Rebuild only when this card's relation to the hovered subject changes.
class MatrixHoverBuilder extends StatefulWidget {
  const MatrixHoverBuilder({
    super.key,
    required this.subject,
    required this.highlight,
    required this.builder,
  });
  final Subject subject;
  final ValueListenable<Subject?> highlight;
  final Widget Function(BuildContext, Subject?) builder;
  @override
  State<MatrixHoverBuilder> createState() => _MatrixHoverBuilderState();
}

class _MatrixHoverBuilderState extends State<MatrixHoverBuilder> {
  late (bool, bool, bool, bool) _appearance;
  (bool, bool, bool, bool) _relation() {
    final selected = widget.highlight.value;
    final subject = widget.subject;
    return (
      selected != null,
      selected?.id == subject.id,
      selected?.prereqs.any(
            (ref) => ref == subject.id || ref == subject.code,
          ) ??
          false,
      selected != null &&
          subject.prereqs.any(
            (ref) => ref == selected.id || ref == selected.code,
          ),
    );
  }

  @override
  void initState() {
    super.initState();
    _appearance = _relation();
    widget.highlight.addListener(_changed);
  }

  @override
  void didUpdateWidget(MatrixHoverBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlight != widget.highlight) {
      oldWidget.highlight.removeListener(_changed);
      widget.highlight.addListener(_changed);
    }
    _appearance = _relation();
  }

  void _changed() {
    final next = _relation();
    if (next != _appearance) setState(() => _appearance = next);
  }

  @override
  void dispose() {
    widget.highlight.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.highlight.value);
}
