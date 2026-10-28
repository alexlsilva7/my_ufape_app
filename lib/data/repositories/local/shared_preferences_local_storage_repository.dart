import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/local_storage_repository.dart';
import '../../../core/exceptions/persistence_exception.dart';

class SharedPreferencesLocalStorageRepository
    implements ReloadableLocalStorageRepository {
  Future<SharedPreferences>? _preferences;
  Future<SharedPreferences> get _store =>
      _preferences ??= SharedPreferences.getInstance();

  @override
  Future<Map<String, String>> readAll() async {
    final store = await _store;
    return {
      for (final key in store.getKeys())
        if (store.get(key) case final String value) key: value,
    };
  }

  @override
  Future<Map<String, String>> readPersisted() async {
    await (await _store).reload();
    return readAll();
  }

  @override
  Future<void> write(String key, String value) async {
    if (!await (await _store).setString(key, value)) {
      throw PersistenceException(
        'Não foi possível salvar as alterações neste dispositivo.',
        key: key,
      );
    }
  }

  @override
  Future<void> remove(String key) async {
    if (!await (await _store).remove(key)) {
      throw PersistenceException(
        'Não foi possível remover os dados salvos neste dispositivo.',
        key: key,
      );
    }
  }
}
