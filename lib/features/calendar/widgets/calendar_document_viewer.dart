import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calendar_view_model.dart';
import 'calendar_controls.dart';

class CalendarDocumentViewer extends StatefulWidget {
  const CalendarDocumentViewer({
    super.key,
    required this.page,
    required this.onPageChanged,
    required this.onCurrentMonth,
    required this.onDownload,
  });
  final int page;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onCurrentMonth;
  final VoidCallback onDownload;
  @override
  State<CalendarDocumentViewer> createState() => _CalendarDocumentViewerState();
}

class _CalendarDocumentViewerState extends State<CalendarDocumentViewer> {
  int get page => widget.page;
  final transform = TransformationController();
  final focus = FocusNode();
  Size viewportSize = Size.zero;
  double scale = 1;

  @override
  void didUpdateWidget(CalendarDocumentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) reset();
  }

  @override
  void dispose() {
    transform.dispose();
    focus.dispose();
    super.dispose();
  }

  double get widthFitScale {
    final width = viewportSize.width;
    final height = viewportSize.height;
    if (width <= 0 || height <= 0) return 1;
    return math.max(
      1,
      width / math.min(width, height / calendarPageAspectRatio),
    );
  }

  void change(int value) => widget.onPageChanged(value);

  void _showCurrentMonth() {
    widget.onCurrentMonth();
    setState(reset);
  }

  void reset() {
    scale = 1;
    transform.value = Matrix4.identity();
  }

  void zoom(double factor) {
    _zoomTo(scale * factor);
  }

  void _zoomTo(double requested, {Offset? focalPoint}) {
    final current = transform.value.getMaxScaleOnAxis();
    final next = requested.clamp(1.0, 4.0).toDouble();
    if ((next - current).abs() < 1e-6) return;
    final focal = focalPoint ?? viewportSize.center(Offset.zero);
    final factor = next / current;
    transform.value = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(factor, factor, factor, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
      ..multiply(transform.value);
    setState(() => scale = next);
  }

  void _onViewerPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !HardwareKeyboard.instance.isControlPressed ||
        event.scrollDelta.dy == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final current = transform.value.getMaxScaleOnAxis();
      final next = current * math.exp(-event.scrollDelta.dy / 200);
      _zoomTo(next, focalPoint: event.localPosition);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CalendarControls(
        page: page,
        scale: scale,
        onPrevious: page > 1 ? () => change(page - 1) : null,
        onNext: page < 16 ? () => change(page + 1) : null,
        onPageChanged: change,
        onZoomOut: () => zoom(1 / 1.25),
        onZoomIn: () => zoom(1.25),
        onFitPage: () => setState(reset),
        onFitWidth: () => _zoomTo(widthFitScale),
        onCurrentMonth: _showCurrentMonth,
        onDownload: widget.onDownload,
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
            final fittedPageWidth = math.min(
              constraints.maxWidth,
              constraints.maxHeight / calendarPageAspectRatio,
            );
            final displayWidth = fittedPageWidth * scale;
            final physicalDisplayWidth =
                displayWidth * MediaQuery.devicePixelRatioOf(context);
            final imageResolution = physicalDisplayWidth > 1600
                ? 2400
                : displayWidth < 700
                ? 800
                : 1600;

            return KeyboardListener(
              focusNode: focus,
              onKeyEvent: (event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.equal ||
                      event.logicalKey == LogicalKeyboardKey.add) {
                    zoom(1.25);
                  }
                  if (event.logicalKey == LogicalKeyboardKey.minus) {
                    zoom(1 / 1.25);
                  }
                  if (event.logicalKey == LogicalKeyboardKey.digit0) {
                    setState(reset);
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    change(page + 1);
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    change(page - 1);
                  }
                }
              },
              child: GestureDetector(
                onTap: focus.requestFocus,
                onDoubleTap: () => scale > 1 ? setState(reset) : zoom(2),
                child: Listener(
                  onPointerSignal: _onViewerPointerSignal,
                  child: InteractiveViewer(
                    transformationController: transform,
                    minScale: 1,
                    maxScale: 4,
                    // Only the Ctrl + wheel listener above should zoom; keep
                    // ordinary wheel and trackpad scrolling from moving the page.
                    scaleFactor: double.infinity,
                    trackpadScrollCausesScale: true,
                    onInteractionEnd: (_) {
                      setState(
                        () => scale = transform.value.getMaxScaleOnAxis(),
                      );
                    },
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Image.asset(
                        'assets/calendar/page-${page.toString().padLeft(2, '0')}-$imageResolution.webp',
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stack) => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Não foi possível abrir a página do calendário.',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Ctrl + roda do mouse para ampliar · arraste ou use pinça para mover e ampliar. Teclas +, − e 0 controlam o zoom.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}
