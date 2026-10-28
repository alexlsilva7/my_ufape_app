import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/exceptions/persistence_exception.dart';
import '../../../domain/repositories/local_storage_repository.dart';

abstract interface class PersonalStorageRepository implements Listenable {
  Map<String, String> get snapshot;
  bool get isSaving;
  bool get hasPendingChanges;
  String? get errorMessage;
  Future<void> initialize();
  String? read(String key);
  void seed(Map<String, String> values);
  Future<void> write(String key, String? value);
  Future<void> writeAll(Map<String, String?> values);
  Future<void> flush();
  Future<void> retry();
  Future<bool> replace(Map<String, String?> values);
  void dispose();
  static dynamic decode(String? value) {
    try {
      return value == null ? null : jsonDecode(value);
    } catch (_) {
      return null;
    }
  }
}

class _WriteIntent {
  const _WriteIntent(this.value);
  final String? value;
}

class _WriteFailure {
  const _WriteFailure(this.error, this.stack);
  final PersistenceException error;
  final StackTrace stack;
}

/// Edits are optimistic. Each returned Future confirms its batch; ignored
/// Futures are observed by the queue and failures remain visible until saved.
class PersonalStorageRepositoryImpl extends ChangeNotifier
    implements PersonalStorageRepository {
  PersonalStorageRepositoryImpl(this._storage) : _detached = false;
  PersonalStorageRepositoryImpl.detached(this._storage) : _detached = true;
  final LocalStorageRepository _storage;
  final bool _detached;
  final Map<String, String> _values = {};
  // Only platform-confirmed values may suppress a write. Optimistic failures
  // and pending versions must still reach storage when retried.
  final Map<String, String?> _confirmed = {};
  final Map<String, _WriteIntent> _unsaved = {};
  final Map<String, _WriteIntent> _latest = {};
  final Map<String, _WriteFailure> _failures = {};
  bool _ready = false, _disposed = false;
  int _queued = 0;
  Future<void> _pending = Future.value();
  Future<void>? _initializing;

  @override
  Map<String, String> get snapshot => Map.unmodifiable(_values);
  @override
  bool get isSaving => _queued > 0;
  @override
  bool get hasPendingChanges => _unsaved.isNotEmpty;
  @override
  String? get errorMessage => _failures.values.firstOrNull?.error.message;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> initialize() {
    if (_ready) return Future.value();
    return _initializing ??= _loadInitialValues();
  }

  Future<void> _loadInitialValues() async {
    try {
      final persisted = await _storage.readAll();
      _confirmed.addAll(persisted);
      for (final entry in persisted.entries) {
        // A first write can start initialization. Preserve optimistic edits,
        // including removals, instead of replacing them with older device data.
        if (!_latest.containsKey(entry.key)) {
          _values.putIfAbsent(entry.key, () => entry.value);
        }
      }
      _ready = true;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  @override
  String? read(String key) => _values[key];
  @override
  void seed(Map<String, String> values) => _values.addAll(values);

  @override
  Future<void> write(String key, String? value) => writeAll({key: value});

  @override
  Future<void> writeAll(Map<String, String?> values) {
    final intents = <String, _WriteIntent>{};
    for (final entry in values.entries) {
      if (entry.value == null) {
        _values.remove(entry.key);
      } else {
        _values[entry.key] = entry.value!;
      }
      if (_ready &&
          !_unsaved.containsKey(entry.key) &&
          _confirmed[entry.key] == entry.value) {
        continue;
      }
      intents[entry.key] = _WriteIntent(entry.value);
    }
    if (intents.isEmpty) return Future.value();
    // Detached snapshots are only used for legacy backup migration.
    if (_detached) return Future.value();
    _unsaved.addAll(intents);
    _latest.addAll(intents);
    ++_queued;
    final operation = _pending.then((_) async {
      _WriteFailure? failure;
      for (final entry in intents.entries) {
        try {
          if (!_ready) await initialize();
          final value = entry.value.value;
          if (value == null) {
            await _storage.remove(entry.key);
          } else {
            await _storage.write(entry.key, value);
          }
          _confirmed[entry.key] = value;
          if (identical(_unsaved[entry.key], entry.value)) {
            _unsaved.remove(entry.key);
            _failures.remove(entry.key);
          }
        } catch (error, stack) {
          final failed = _WriteFailure(
            error is PersistenceException
                ? error
                : PersistenceException(
                    'Não foi possível salvar as alterações neste dispositivo.',
                    key: entry.key,
                    cause: error,
                  ),
            stack,
          );
          failure ??= failed;
          if (identical(_unsaved[entry.key], entry.value)) {
            _failures[entry.key] = failed;
          }
        }
      }
      --_queued;
      _notify();
      if (failure != null) {
        Error.throwWithStackTrace(failure.error, failure.stack);
      }
    });
    // Awaiting operation still throws. The queue observes failures for optimistic
    // callers and stays usable; flush never consumes a failure as acknowledgement.
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _notify();
    return operation;
  }

  @override
  Future<void> flush() async {
    Future<void> observed;
    do {
      observed = _pending;
      await observed;
    } while (!identical(observed, _pending));
    final failure = _failures.values.firstOrNull;
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stack);
    }
  }

  @override
  Future<void> retry() async {
    await _pending;
    final values = <String, String?>{
      for (final key in _failures.keys)
        if (_unsaved.containsKey(key)) key: _unsaved[key]!.value,
    };
    await writeAll(values);
    await flush();
  }

  @override
  Future<bool> replace(Map<String, String?> values) async {
    await flush();
    final previous = {for (final key in values.keys) key: read(key)};
    final saving = writeAll(values);
    final attempted = {for (final key in values.keys) key: _latest[key]};
    try {
      await saving;
      await flush();
      return true;
    } catch (error, stack) {
      try {
        await writeAll({
          for (final entry in previous.entries)
            if (identical(_latest[entry.key], attempted[entry.key]))
              entry.key: entry.value,
        });
        await flush();
      } catch (_) {
        // Failed rollback remains observable and can be retried as well.
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
