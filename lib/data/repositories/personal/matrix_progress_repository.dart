import 'dart:convert';
import 'dart:math' as math;

import '../../../core/models.dart';
import '../../../domain/academic_rules.dart';
import 'personal_storage_repository.dart';

/// Stores personal matrix edits while preserving official curriculum metadata.
abstract interface class MatrixProgressRepository {
  dynamic decode(String? value);
  Future<void> flush();
  Future<void> retry();
  List<Subject> restore(
    String course,
    CurriculumProfile? profile, {
    List<JsonMap>? importedSubjects,
  });
  Future<void> save(
    String course,
    String profile,
    List<Subject> subjects,
    bool Function(Object) isCompleted,
  );
  double hours(String course, String profile, String type);
  Future<void> setHours(
    String course,
    String profile, {
    double? acex,
    double? acc,
  });
}

class MatrixProgressRepositoryImpl implements MatrixProgressRepository {
  MatrixProgressRepositoryImpl(this.storage);
  final PersonalStorageRepository storage;
  String? _read(String key) => storage.read(key);
  @override
  dynamic decode(String? value) => PersonalStorageRepository.decode(value);
  @override
  Future<void> flush() => storage.flush();
  @override
  Future<void> retry() => storage.retry();
  @override
  List<Subject> restore(
    String course,
    CurriculumProfile? profile, {
    List<JsonMap>? importedSubjects,
  }) {
    final progressKey = '${course}_matriz_progress_${profile?.id}';
    List<Subject> subjects;
    if (profile == null) {
      return [];
    }
    final saved = decode(
      _read(progressKey) ??
          (course == 'bcc'
              ? _read(
                  profile.id == 'BCC02'
                      ? 'bcc_matriz_progress_antiga'
                      : 'bcc_matriz_progress',
                )
              : null),
    );
    final savedItems = importedSubjects ?? asList(saved).map(asMap).toList();
    subjects = profile.subjects.map((s) {
      final old =
          savedItems.reversed.where((e) => e['id'] == s.id).firstOrNull ??
          (s.code?.isNotEmpty == true
              ? savedItems.reversed
                    .where(
                      (e) =>
                          textOf(e['code']).trim().toUpperCase() ==
                          s.code!.trim().toUpperCase(),
                    )
                    .firstOrNull
              : null);
      return Subject.fromJson({
        ...s.toJson(),
        'status': ['pendente', 'cursando', 'concluido'].contains(old?['status'])
            ? old!['status']
            : 'pendente',
        'grade': AcademicGrades.normalize(textOf(old?['grade'])) ?? '',
        if (s.isGenericElective && old != null)
          'electiveSelection': old['electiveSelection'],
      }, profile: profile.id);
    }).toList();
    final used = <String>{};
    final fixedElectives = subjects
        .where(
          (s) =>
              s.isElective &&
              !s.isGenericElective &&
              s.electiveSelection == null &&
              (s.period ?? 0) > 0,
        )
        .map(
          (s) => s.code?.trim().isNotEmpty == true
              ? 'code:${normalized(s.code!)}'
              : 'name:${normalized(s.name)}',
        )
        .toSet();
    subjects = subjects.map((s) {
      final selection = s.electiveSelection;
      if (selection?.source == 'catalog' &&
          (fixedElectives.contains(selection!.identity) ||
              !used.add(selection.identity))) {
        final raw = s.toJson()..remove('electiveSelection');
        return Subject.fromJson(raw, profile: profile.id);
      }
      return s;
    }).toList();
    for (final raw in savedItems) {
      final s = Subject.fromJson(raw, profile: profile.id);
      if (s.additionalElective &&
          RegExp(
            r'^personal_opt_[a-z0-9_-]+$',
            caseSensitive: false,
          ).hasMatch(s.id) &&
          s.electiveSelection != null &&
          !subjects.any((e) => e.id == s.id) &&
          !ElectiveAssignments.isAssigned(subjects, s.electiveSelection!)) {
        subjects.add(
          Subject.fromJson({
            'id': s.id,
            'name': 'Optativa adicional',
            'type': 'optativa',
            'period': profile.subjects.fold<int>(
              1,
              (max, s) => math.max(max, s.period ?? 0),
            ),
            'additionalElective': true,
            'electiveSelection': s.electiveSelection!.toJson(),
            'status':
                ['pendente', 'cursando', 'concluido'].contains(raw['status'])
                ? raw['status']
                : 'pendente',
            'grade': AcademicGrades.normalize(textOf(raw['grade'])) ?? '',
          }, profile: profile.id),
        );
      }
    }
    return subjects;
  }

  @override
  Future<void> save(
    String course,
    String profile,
    List<Subject> subjects,
    bool Function(Object) isCompleted,
  ) {
    final progressKey = '${course}_matriz_progress_$profile';
    final encoded = jsonEncode(
      subjects
          .map(
            (s) => {
              ...s.toJson(),
              'status': isCompleted(s)
                  ? 'concluido'
                  : textOf(s.raw['status'], 'pendente'),
            },
          )
          .toList(),
    );
    return storage.writeAll({
      progressKey: encoded,
      if (course == 'bcc')
        profile == 'BCC02'
                ? 'bcc_matriz_progress_antiga'
                : 'bcc_matriz_progress':
            encoded,
    });
  }

  @override
  double hours(String course, String profile, String type) {
    final n = numberOf(
      _read('${course}_${type}_hours_$profile') ??
          (course == 'bcc' && profile == 'BCC03'
              ? _read('bcc_${type}_hours')
              : null),
    );
    return n.isFinite && n >= 0 ? n : 0;
  }

  @override
  Future<void> setHours(
    String course,
    String profile, {
    double? acex,
    double? acc,
  }) {
    final values = <String, String?>{};
    for (final entry in {'acex': acex, 'acc': acc}.entries) {
      if (entry.value == null) continue;
      final value = entry.value!;
      if (!value.isFinite || value < 0) continue;
      values['${course}_${entry.key}_hours_$profile'] = '$value';
      if (course == 'bcc' && profile == 'BCC03') {
        values['bcc_${entry.key}_hours'] = '$value';
      }
    }
    return storage.writeAll(values);
  }
}
