import 'package:flutter/material.dart';

class ScheduleSessionPlacement {
  const ScheduleSessionPlacement({
    required this.id,
    required this.bounds,
    required this.child,
  });

  final String id;
  final Rect bounds;
  final Widget child;
}

class _SessionEntry {
  _SessionEntry(this.placement, this.controller);
  ScheduleSessionPlacement placement;
  final AnimationController controller;
}

/// Retains only departing sessions until their fade finishes. Stable sessions
/// keep their controller and animate geometry when automatic shifts change.
class ScheduleSessionLayer extends StatefulWidget {
  const ScheduleSessionLayer({
    super.key,
    required this.placements,
    required this.duration,
  });

  final List<ScheduleSessionPlacement> placements;
  final Duration duration;

  @override
  State<ScheduleSessionLayer> createState() => _ScheduleSessionLayerState();
}

class _ScheduleSessionLayerState extends State<ScheduleSessionLayer>
    with TickerProviderStateMixin {
  final _entries = <String, _SessionEntry>{};
  Set<String> get _currentIds => widget.placements.map((p) => p.id).toSet();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ScheduleSessionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final current = _currentIds;
    for (final placement in widget.placements) {
      final entry = _entries.putIfAbsent(
        placement.id,
        () => _SessionEntry(
          placement,
          AnimationController(
            vsync: this,
            duration: widget.duration,
            reverseDuration: const Duration(milliseconds: 160),
          ),
        ),
      );
      entry.placement = placement;
      entry.controller.duration = widget.duration;
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

  Future<void> _removeAfterExit(String id, _SessionEntry entry) async {
    try {
      await entry.controller.reverse().orCancel;
      if (!mounted ||
          _currentIds.contains(id) ||
          !identical(_entries[id], entry)) {
        return;
      }
      setState(() => _entries.remove(id));
      entry.controller.dispose();
    } on TickerCanceled {
      // A quick re-selection or disposal cancels the pending removal.
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
    final current = _currentIds;
    return Stack(
      children: [
        for (final entry in _entries.values)
          if (widget.duration == Duration.zero)
            Positioned.fromRect(
              key: ValueKey(entry.placement.id),
              rect: entry.placement.bounds,
              child: entry.placement.child,
            )
          else
            AnimatedPositioned.fromRect(
              key: ValueKey(entry.placement.id),
              duration: widget.duration,
              curve: Curves.easeInOutCubic,
              rect: entry.placement.bounds,
              child: IgnorePointer(
                ignoring: !current.contains(entry.placement.id),
                child: ExcludeFocus(
                  excluding: !current.contains(entry.placement.id),
                  child: ExcludeSemantics(
                    excluding: !current.contains(entry.placement.id),
                    child: FadeTransition(
                      opacity: entry.controller.drive(
                        CurveTween(curve: Curves.easeOutCubic),
                      ),
                      child: ScaleTransition(
                        alignment: Alignment.topCenter,
                        scale: entry.controller.drive(
                          Tween(
                            begin: .97,
                            end: 1.0,
                          ).chain(CurveTween(curve: Curves.easeOutCubic)),
                        ),
                        child: entry.placement.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
