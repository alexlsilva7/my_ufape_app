import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/models.dart';
import '../../../domain/academic_rules.dart';
import 'personal_storage_repository.dart';

abstract interface class CompletionRepository implements Listenable {
  String keyFor(String course);
  Set<String> completedFor(String course);
  bool isCompleted(String course, Object item);
  Future<void> setCompleted(String course, Object item, bool completed);
  Future<void> replace(String course, Set<String> values);
  Future<void> migrate(String course, List<Subject> completionCatalog);
  void dispose();
}

class CompletionRepositoryImpl extends ChangeNotifier
    implements CompletionRepository {
  CompletionRepositoryImpl(this.storage);
  final PersonalStorageRepository storage;
  final _completed = <String, (String?, Set<String>)>{};
  @override
  String keyFor(String course) =>
      'completedDisciplines_${course.toLowerCase()}';
  String? _read(String key) => storage.read(key);
  Future<void> _write(String key, String? value) => storage.write(key, value);
  dynamic _json(String? value) => PersonalStorageRepository.decode(value);
  @override
  Set<String> completedFor(String course) {
    final key = keyFor(course);
    final encoded = _read(key);
    final cached = _completed[key];
    if (cached != null && cached.$1 == encoded) return cached.$2;
    final values = Set<String>.unmodifiable(
      asList(_json(encoded))
          .whereType<String>()
          .map((e) => e.startsWith('id:') ? e : e.trim().toUpperCase()),
    );
    _completed[key] = (encoded, values);
    return values;
  }

  @override
  bool isCompleted(String course, Object item) =>
      completedFor(course).contains(CompletionIdentity.of(item));
  @override
  Future<void> setCompleted(String course, Object item, bool completed) {
    final values = Set<String>.of(completedFor(course));
    if (completed) {
      values.add(CompletionIdentity.of(item));
    } else {
      values.remove(CompletionIdentity.of(item));
    }
    return replace(course, values);
  }

  @override
  Future<void> replace(String course, Set<String> values) {
    final encoded = jsonEncode(values.toList()..sort());
    final changed = encoded != _read(keyFor(course));
    final saving = _write(keyFor(course), encoded);
    if (changed) notifyListeners();
    return saving;
  }

  @override
  Future<void> migrate(String course, List<Subject> completionCatalog) {
    final courseId = course;
    final completionKey = keyFor(course);
    final completedDisciplines = completedFor(course);

    String resolveLegacy(String value, String profile) {
      if (value.startsWith('id:')) return value;
      final matches = completionCatalog
          .where(
            (s) =>
                s.id == value &&
                (profile == 'all' ||
                    profile == 'unassigned' ||
                    s.profile == profile),
          )
          .map(CompletionIdentity.of)
          .toSet();
      if (matches.length == 1) return matches.single;
      if (matches.length > 1) {
        return 'id:${Uri.encodeComponent(profile)}:${Uri.encodeComponent(value)}';
      }
      final code = value.trim().toUpperCase();
      if (completionCatalog.any((s) => s.code?.trim().toUpperCase() == code)) {
        return code;
      }
      return 'id:${Uri.encodeComponent(profile)}:${Uri.encodeComponent(value)}';
    }

    String resolveScoped(String entry) {
      if (!entry.startsWith('id:')) return entry.trim().toUpperCase();
      final separator = entry.indexOf(':', 3);
      if (separator < 0) return entry;
      try {
        final profile = Uri.decodeComponent(entry.substring(3, separator));
        final id = Uri.decodeComponent(entry.substring(separator + 1));
        return resolveLegacy(id, profile);
      } catch (_) {
        return entry;
      }
    }

    if (_read(completionKey) != null) {
      final resolved = completedDisciplines.map(resolveScoped).toSet().toList()
        ..sort();
      return _write(completionKey, jsonEncode(resolved));
    }
    final completed = <String>{};
    for (final entry in storage.snapshot.entries.toList()) {
      String? profile;
      if (entry.key.startsWith('${courseId}_matriz_progress_')) {
        profile = entry.key.substring('${courseId}_matriz_progress_'.length);
      }
      if (courseId == 'bcc' && entry.key == 'bcc_matriz_progress') {
        profile = 'BCC03';
      }
      if (courseId == 'bcc' && entry.key == 'bcc_matriz_progress_antiga') {
        profile = 'BCC02';
      }
      if (profile != null) {
        for (final raw in asList(_json(entry.value)).map(asMap)) {
          if (raw['status'] == 'concluido') {
            completed.add(
              resolveScoped(
                CompletionIdentity.of(Subject.fromJson(raw, profile: profile)),
              ),
            );
          }
        }
      }
      final prefix = '${completionKey}_';
      if (entry.key.startsWith(prefix) ||
          (courseId == 'bcc' && entry.key == 'completedDisciplines')) {
        var p = entry.key == 'completedDisciplines'
            ? 'BCC03'
            : entry.key.substring(prefix.length);
        if (p == 'nova') p = 'BCC03';
        if (p == 'antiga') p = 'BCC02';
        for (final value in asList(_json(entry.value)).whereType<String>()) {
          completed.add(resolveLegacy(value, p));
        }
      }
    }
    return _write(completionKey, jsonEncode(completed.toList()..sort()));
  }
}
