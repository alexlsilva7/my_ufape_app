import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'academic_motion.dart';

class AcademicMenuAction {
  const AcademicMenuAction(
    this.label,
    this.icon,
    this.onSelected, {
    this.checked = false,
    this.dividerBefore = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onSelected;
  final bool checked, dividerBefore;
}

/// Shares browser-menu ownership across cards, including animated departures.
/// The previous browser setting is restored when the last card is disposed.
class _BrowserMenuLease {
  static int _users = 0;
  static bool? _wasEnabled;
  static Future<void> _updates = Future.value();

  static void acquire() {
    if (!kIsWeb) return;
    _users++;
    _sync();
  }

  static void release() {
    if (!kIsWeb) return;
    _users--;
    _sync();
  }

  static void _sync() {
    _updates = _updates
        .then((_) async {
          if (_users > 0) {
            _wasEnabled ??= BrowserContextMenu.enabled;
            if (BrowserContextMenu.enabled) {
              await BrowserContextMenu.disableContextMenu();
            }
          } else {
            final restore = _wasEnabled;
            _wasEnabled = null;
            if (restore == true) await BrowserContextMenu.enableContextMenu();
          }
        })
        .catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'academic context menu',
            ),
          );
        });
  }
}

class AcademicContextMenu extends StatefulWidget {
  const AcademicContextMenu({
    super.key,
    required this.actions,
    required this.child,
  });

  final List<AcademicMenuAction> actions;
  final Widget child;

  @override
  State<AcademicContextMenu> createState() => _AcademicContextMenuState();
}

class _AcademicContextMenuState extends State<AcademicContextMenu> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _BrowserMenuLease.acquire();
  }

  @override
  void dispose() {
    _BrowserMenuLease.release();
    super.dispose();
  }

  Future<void> _show(Offset globalPosition) async {
    if (_open) return;
    _open = true;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final position = overlay.globalToLocal(globalPosition);
    try {
      final action = await showMenu<VoidCallback>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromLTWH(position.dx, position.dy, 0, 0),
          Offset.zero & overlay.size,
        ),
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 360),
        popUpAnimationStyle: academicDialogMotion(context),
        items: [
          for (final action in widget.actions) ...[
            if (action.dividerBefore) const PopupMenuDivider(),
            PopupMenuItem<VoidCallback>(
              value: action.onSelected,
              enabled: action.onSelected != null,
              child: Row(
                spacing: 12,
                children: [
                  Icon(action.icon, size: 18),
                  Expanded(child: Text(action.label)),
                  if (action.checked) const Icon(Icons.check, size: 18),
                ],
              ),
            ),
          ],
        ],
      );
      if (mounted) action?.call();
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.contextMenu ||
              (event.logicalKey == LogicalKeyboardKey.f10 &&
                  HardwareKeyboard.instance.isShiftPressed))) {
        final box = context.findRenderObject()! as RenderBox;
        _show(box.localToGlobal(box.size.center(Offset.zero)));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onSecondaryTapUp: (details) => _show(details.globalPosition),
      child: widget.child,
    ),
  );
}
