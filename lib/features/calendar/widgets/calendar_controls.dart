import 'package:flutter/material.dart';

class CalendarControls extends StatelessWidget {
  const CalendarControls({
    super.key,
    required this.page,
    required this.scale,
    required this.onPrevious,
    required this.onNext,
    required this.onPageChanged,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onFitPage,
    required this.onFitWidth,
    required this.onCurrentMonth,
    required this.onDownload,
  });

  final int page;
  final double scale;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onFitPage;
  final VoidCallback onFitWidth;
  final VoidCallback onCurrentMonth;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Padding(
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
          onPressed: onPrevious,
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
          onChanged: (value) {
            if (value != null) onPageChanged(value);
          },
        ),
        IconButton(
          tooltip: 'Próxima página',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          tooltip: 'Diminuir zoom',
          onPressed: onZoomOut,
          icon: const Icon(Icons.zoom_out),
        ),
        IconButton(
          tooltip: 'Aumentar zoom',
          onPressed: onZoomIn,
          icon: const Icon(Icons.zoom_in),
        ),
        Text('${(scale * 100).round()}%'),
        TextButton.icon(
          onPressed: onFitPage,
          icon: const Icon(Icons.fit_screen),
          label: const Text('Ajustar página'),
        ),
        TextButton.icon(
          onPressed: onFitWidth,
          icon: const Icon(Icons.width_full),
          label: const Text('Ajustar largura'),
        ),
        TextButton(onPressed: onCurrentMonth, child: const Text('Mês atual')),
        OutlinedButton.icon(
          onPressed: onDownload,
          icon: const Icon(Icons.download),
          label: const Text('PDF original'),
        ),
      ],
    ),
  );
}
