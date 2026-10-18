import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/files.dart';

const calendarPageAspectRatio = 3395 / 2400;

/// Uses São Paulo (UTC−3), including when the device has another timezone.
int academicCalendarPage(DateTime now) {
  final date = now.toUtc().subtract(const Duration(hours: 3));
  final month = '${date.year}-${date.month.toString().padLeft(2, '0')}';
  const months = {
    '2026-03': 1,
    '2026-04': 2,
    '2026-05': 3,
    '2026-06': 5,
    '2026-07': 6,
    '2026-08': 7,
    '2026-09': 8,
    '2026-10': 9,
    '2026-11': 11,
    '2026-12': 12,
    '2027-01': 13,
    '2027-02': 14,
    '2027-03': 15,
    '2027-04': 16,
  };
  for (final entry in months.entries) {
    if (month.compareTo(entry.key) <= 0) return entry.value;
  }
  return 16;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int page = academicCalendarPage(DateTime.now());
  final transform = TransformationController();
  final focus = FocusNode();
  Size viewportSize = Size.zero;
  double scale = 1;
  late Timer monthTimer;
  String month = '';
  @override
  void initState() {
    super.initState();
    month = _month();
    monthTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = _month();
      if (month != next) {
        month = next;
        change(academicCalendarPage(DateTime.now()));
      }
    });
  }

  String _month() => DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 3))
      .toIso8601String()
      .substring(0, 7);

  double get widthFitScale {
    final width = viewportSize.width;
    final height = viewportSize.height;
    if (width <= 0 || height <= 0) return 1;
    return math.max(
      1,
      width / math.min(width, height / calendarPageAspectRatio),
    );
  }

  void change(int value) {
    setState(() {
      page = value.clamp(1, 16);
      reset();
    });
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
  void dispose() {
    monthTimer.cancel();
    transform.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Calendário acadêmico · 2026/2027',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              tooltip: 'Página anterior',
              onPressed: page > 1 ? () => change(page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            DropdownButton<int>(
              value: page,
              items: List.generate(
                16,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('Página ${i + 1} / 16'),
                ),
              ),
              onChanged: (v) => change(v!),
            ),
            IconButton(
              tooltip: 'Próxima página',
              onPressed: page < 16 ? () => change(page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'Diminuir zoom',
              onPressed: () => zoom(1 / 1.25),
              icon: const Icon(Icons.zoom_out),
            ),
            IconButton(
              tooltip: 'Aumentar zoom',
              onPressed: () => zoom(1.25),
              icon: const Icon(Icons.zoom_in),
            ),
            Text('${(scale * 100).round()}%'),
            TextButton.icon(
              onPressed: () => setState(reset),
              icon: const Icon(Icons.fit_screen),
              label: const Text('Ajustar página'),
            ),
            TextButton.icon(
              onPressed: () => _zoomTo(widthFitScale),
              icon: const Icon(Icons.width_full),
              label: const Text('Ajustar largura'),
            ),
            TextButton(
              onPressed: () => change(academicCalendarPage(DateTime.now())),
              child: const Text('Mês atual'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final data = await rootBundle.load(
                    'assets/calendar/calendario-academico-ufape-2026.pdf',
                  );
                  await saveBytes(
                    'calendario-academico-ufape-2026.pdf',
                    data.buffer.asUint8List(),
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Falha ao salvar PDF: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('PDF original'),
            ),
          ],
        ),
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
