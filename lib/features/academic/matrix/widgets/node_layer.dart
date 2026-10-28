import 'dart:math' as math;

import 'package:flutter/material.dart';

class MatrixNode {
  const MatrixNode({
    required this.id,
    required this.bounds,
    required this.child,
  });

  final String id;
  final Rect bounds;
  final Widget child;
}

class _NodeEntry {
  _NodeEntry(this.node, this.controller, this.delay);

  MatrixNode node;
  final AnimationController controller;
  final int delay;
}

/// Stable cards retain their state while filtering, moving or changing height.
/// Departing cards remain painted only until their short exit has finished.
class MatrixNodeLayer extends StatefulWidget {
  const MatrixNodeLayer({
    super.key,
    required this.nodes,
    required this.duration,
  });

  final List<MatrixNode> nodes;
  final Duration duration;

  @override
  State<MatrixNodeLayer> createState() => _MatrixNodeLayerState();
}

class _MatrixNodeLayerState extends State<MatrixNodeLayer>
    with TickerProviderStateMixin {
  final _entries = <String, _NodeEntry>{};
  Set<String> get _current => widget.nodes.map((node) => node.id).toSet();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(MatrixNodeLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final current = _current;
    for (var i = 0; i < widget.nodes.length; i++) {
      final node = widget.nodes[i];
      final entry = _entries.putIfAbsent(node.id, () {
        final delay = math.min(i, 6) * 16;
        return _NodeEntry(
          node,
          AnimationController(
            vsync: this,
            duration: widget.duration + Duration(milliseconds: delay),
            reverseDuration: const Duration(milliseconds: 140),
          ),
          delay,
        );
      });
      entry.node = node;
      entry.controller.duration =
          widget.duration + Duration(milliseconds: entry.delay);
      if (widget.duration == Duration.zero) {
        entry.controller.value = 1;
      } else if (entry.controller.status != AnimationStatus.forward &&
          entry.controller.status != AnimationStatus.completed) {
        entry.controller.forward();
      }
    }
    for (final id in _entries.keys.toList()) {
      if (current.contains(id)) continue;
      final entry = _entries[id]!;
      if (widget.duration == Duration.zero) {
        _entries.remove(id);
        entry.controller.dispose();
      } else if (entry.controller.status != AnimationStatus.reverse) {
        _removeAfterExit(id, entry);
      }
    }
  }

  Future<void> _removeAfterExit(String id, _NodeEntry entry) async {
    try {
      await entry.controller.reverse().orCancel;
      if (!mounted || _current.contains(id) || _entries[id] != entry) return;
      setState(() => _entries.remove(id));
      entry.controller.dispose();
    } on TickerCanceled {
      // Rapid filter changes resume the same card instead of duplicating it.
    }
  }

  @override
  void dispose() {
    for (final entry in _entries.values) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final entry in _entries.values)
          AnimatedPositioned.fromRect(
            key: ValueKey('matrix-node-${entry.node.id}'),
            rect: entry.node.bounds,
            duration: widget.duration,
            curve: Curves.easeInOutCubic,
            child: IgnorePointer(
              ignoring: !current.contains(entry.node.id),
              child: ExcludeFocus(
                excluding: !current.contains(entry.node.id),
                child: ExcludeSemantics(
                  excluding: !current.contains(entry.node.id),
                  child: _sizedAppearance(entry),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sizedAppearance(_NodeEntry entry) {
    final child = _appearance(entry);
    return LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        clipBehavior: constraints.maxHeight < entry.node.bounds.height
            ? Clip.hardEdge
            : Clip.none,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: entry.node.bounds.height,
          maxHeight: entry.node.bounds.height,
          child: child,
        ),
      ),
    );
  }

  Widget _appearance(_NodeEntry entry) {
    if (widget.duration == Duration.zero) return entry.node.child;
    final animation = entry.controller.drive(
      CurveTween(
        curve: Interval(
          entry.delay / (widget.duration.inMilliseconds + entry.delay),
          1,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween(begin: const Offset(0, .055), end: Offset.zero),
        ),
        child: entry.node.child,
      ),
    );
  }
}
