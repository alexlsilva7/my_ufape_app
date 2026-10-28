import 'package:flutter/material.dart';

class HomeStatus extends StatelessWidget {
  const HomeStatus({
    super.key,
    required this.offline,
    required this.error,
    required this.muted,
    required this.onRefresh,
  });
  final bool offline;
  final String? error;
  final Color muted;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Icon(
          offline ? Icons.cloud_off_outlined : Icons.error_outline,
          size: 18,
          color: muted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            offline
                ? 'Consulta offline · cópia local de referência. Os dados publicados podem ter mudado.'
                : error!,
            style: TextStyle(fontSize: 12, height: 1.5, color: muted),
          ),
        ),
        IconButton(
          tooltip: 'Atualizar dados',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 18),
        ),
      ],
    ),
  );
}
