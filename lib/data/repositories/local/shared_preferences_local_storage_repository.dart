import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/local_storage_repository.dart';

class SharedPreferencesLocalStorageRepository
    implements LocalStorageRepository {
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
  Future<void> write(String key, String value) async {
    await (await _store).setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _store).remove(key);
  }
}
