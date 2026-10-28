import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/models.dart';
import 'personal_storage_repository.dart';

/// One active plan, persisted independently for each course and semester.
abstract interface class SchedulePlanRepository implements Listenable {
  String? get course;
  String? get semester;
  List<Discipline> get selected;
  void restore(String? courseId, String term);
  Future<void> replace(Iterable<Discipline> values);
  Future<void> flush();
  Future<void> retry();
  void dispose();
}

class SchedulePlanRepositoryImpl extends ChangeNotifier
    implements SchedulePlanRepository {
  SchedulePlanRepositoryImpl(this.storage);
  final PersonalStorageRepository storage;
  @override
  String? course;
  @override
  String? semester;
  List<Discipline> _selected = [];
  @override
  List<Discipline> get selected => List.unmodifiable(_selected);

  @override
  void restore(String? courseId, String term) {
    course = courseId;
    semester = term;
    final raw = courseId == null
        ? null
        : storage.read('schedule_${courseId}_$term') ??
              (term == '2026.1' ? storage.read('schedule_$courseId') : null);
    _selected = asList(PersonalStorageRepository.decode(raw))
        .map((e) => Discipline.fromJson(asMap(e)))
        .toList();
    notifyListeners();
  }

  @override
  Future<void> replace(Iterable<Discipline> values) {
    _selected = values.toList();
    final encoded = jsonEncode(_selected.map((e) => e.toJson()).toList());
    final saving = storage.writeAll({
      if (course != null) ...{
        'schedule_${course}_$semester': encoded,
        if (semester == '2026.1') 'schedule_$course': encoded,
      },
    });
    notifyListeners();
    return saving;
  }

  @override
  Future<void> flush() => storage.flush();
  @override
  Future<void> retry() => storage.retry();
}
