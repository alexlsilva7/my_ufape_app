import 'package:flutter/material.dart';

import '../../data/repositories/personal/personal_storage_repository.dart';
import '../exceptions/persistence_exception.dart';

/// Observes persistence directly, without rebuilding routes or academic state.
class PersistenceBanner extends StatelessWidget {
  const PersistenceBanner({super.key, required this.storage});
  final PersonalStorageRepository storage;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: storage,
    builder: (context, _) {
      if (storage.errorMessage == null) return const SizedBox.shrink();
      return LayoutBuilder(
        builder: (context, constraints) => Semantics(
          liveRegion: true,
          child: MaterialBanner(
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            leading: const Icon(Icons.save_outlined),
            content: const Text(
              'Há alterações não salvas neste dispositivo. '
              'Elas continuam disponíveis nesta sessão.',
            ),
            forceActionsBelow: constraints.maxWidth < 600,
            actions: [
              TextButton(
                onPressed: storage.isSaving
                    ? null
                    : () async {
                        try {
                          await storage.retry();
                        } on PersistenceException {
                          // The banner remains until every failed write succeeds.
                        }
                      },
                child: Text(
                  storage.isSaving ? 'Salvando…' : 'Tentar salvar novamente',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
