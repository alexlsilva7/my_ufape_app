import 'dart:convert';

import '../../../core/models.dart';
import '../../../domain/repositories/local_storage_repository.dart';
import 'personal_storage_repository.dart';
import 'completion_repository.dart';

abstract interface class BackupRepository {
  String export();
  Future<bool> import(String value, List<CourseMeta> courses);
}

class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl(this.storage);
  final PersonalStorageRepository storage;
  @override
  String export() => jsonEncode({
    for (final key in _staticBackupKeys) key: storage.read(key),
    for (final entry in storage.snapshot.entries)
      if (isBackupStorageKey(entry.key)) entry.key: entry.value,
  });

  @override
  Future<bool> import(String value, List<CourseMeta> courses) async {
    final parsed = PersonalStorageRepository.decode(value);
    if (parsed is! Map || parsed.isEmpty) return false;
    final accepted = <String, String?>{};
    for (final entry in parsed.entries) {
      if (entry.key is! String || !isBackupStorageKey(entry.key)) continue;
      if (entry.value != null && entry.value is! String) return false;
      accepted[entry.key] = entry.value as String?;
    }
    if (accepted.isEmpty) return false;
    // Resolve legacy IDs from the incoming backup alone, before replacing live data.
    final staged = PersonalStorageRepositoryImpl.detached(_DetachedStorage())
      ..seed({
        for (final e in accepted.entries)
          if (e.value != null) e.key: e.value!,
      });
    final completions = CompletionRepositoryImpl(staged);
    try {
      final courseIds = <String>{
        if (staged.read('selectedCourse') != null)
          staged.read('selectedCourse')!,
        ...courses.map((e) => e.id),
      };
      for (final id in courseIds) {
        final key = completions.keyFor(id);
        if (!accepted.containsKey(key) &&
            accepted.keys.any(
              (k) =>
                  k.startsWith('${id}_matriz_progress') ||
                  k.startsWith('completedDisciplines_${id}_') ||
                  id == 'bcc' && k == 'completedDisciplines',
            )) {
          completions.migrate(id, []);
          accepted[key] = staged.read(key);
        }
      }
      return await storage.replace(accepted);
    } finally {
      completions.dispose();
      staged.dispose();
    }
  }
}

const _staticBackupKeys = {
  'themePreference',
  'selectedCourse',
  'selectedSemester',
  'view_preference',
  'saved_gradeTitle',
  'saved_selectedPeriod',
  'saved_selectedProfile',
  'saved_disciplinesList',
  'completedDisciplines',
  'savedGrades',
  'bcc_matriz_progress',
  'bcc_matriz_progress_antiga',
  'bcc_matrix_version',
  'bcc_acex_hours',
  'bcc_acc_hours',
};

bool isBackupStorageKey(String key) =>
    _staticBackupKeys.contains(key) ||
    [
      'schedule_',
      'selected_profile_',
      'disciplines_selectedProfile_',
      'matrix_version_',
    ].any(key.startsWith) ||
    RegExp(
      r'^[a-z0-9_-]+_(?:matriz_progress|acex_hours|acc_hours)_.+$',
      caseSensitive: false,
    ).hasMatch(key) ||
    RegExp(
      r'^completedDisciplines_[a-z0-9_-]+(?:_.+)?$',
      caseSensitive: false,
    ).hasMatch(key);

class _DetachedStorage implements LocalStorageRepository {
  @override
  Future<Map<String, String>> readAll() async => {};
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> remove(String key) async {}
}
