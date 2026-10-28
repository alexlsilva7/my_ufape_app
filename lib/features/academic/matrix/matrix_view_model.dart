import '../../../domain/entities/course_details.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/academic_context.dart';
import '../../../core/models.dart';
import '../../../domain/academic_rules.dart';
import '../../../data/repositories/personal/matrix_progress_repository.dart';
import '../../../data/repositories/personal/completion_repository.dart';
import '../../../data/repositories/personal/schedule_plan_repository.dart';

class MatrixViewModel extends ChangeNotifier {
  MatrixViewModel(
    this.context,
    this.personalProgress,
    this.completions,
    this.plan,
  ) {
    context.addListener(_contextChanged);
    completions.addListener(_completionsChanged);
    plan.addListener(_planChanged);
  }
  final AcademicContext context;
  final MatrixProgressRepository personalProgress;
  final CompletionRepository completions;
  final SchedulePlanRepository plan;
  List<Subject> _subjectValues = [];
  List<Subject>? _subjectView;
  Map<(String, String?), Subject>? _byIdentity;
  Map<String, Subject>? _byId;
  Map<String, List<Subject>>? _byLookup;
  Set<String>? _scheduleIds, _scheduleCodes;
  List<Subject> get _subjects => _subjectValues;
  set _subjects(List<Subject> value) {
    _subjectValues = value;
    _subjectView = null;
    _byIdentity = null;
    _byId = null;
    _byLookup = null;
  }

  List<Subject> get subjects => _subjectView ??= List.unmodifiable(_subjects);
  void _indexSubjects() {
    if (_byIdentity != null) return;
    _byIdentity = {};
    _byId = {};
    _byLookup = {};
    for (final subject in _subjects) {
      _byIdentity!.putIfAbsent((subject.id, subject.profile), () => subject);
      _byId!.putIfAbsent(subject.id, () => subject);
      for (final key in [
        subject.id,
        subject.code,
        subject.name,
      ].whereType<String>().map(normalized).toSet()) {
        (_byLookup![key] ??= []).add(subject);
      }
    }
  }

  void _indexSchedule() {
    if (_scheduleIds != null) return;
    final selected = schedule;
    _scheduleIds = selected.map((entry) => entry.id).toSet();
    _scheduleCodes = selected
        .map((entry) => entry.code?.toUpperCase())
        .whereType<String>()
        .toSet();
  }

  int _editDepth = 0;
  bool _pendingProgress = false, _pendingNotification = false;
  T _edit<T>(T Function() action) {
    ++_editDepth;
    try {
      return action();
    } finally {
      if (--_editDepth == 0) {
        final persist = _pendingProgress, notify = _pendingNotification;
        _pendingProgress = false;
        _pendingNotification = false;
        if (persist) _persistProgress();
        if (notify) notifyListeners();
      }
    }
  }

  @override
  void notifyListeners() {
    if (_editDepth > 0) {
      _pendingNotification = true;
      return;
    }
    if (!_disposed) super.notifyListeners();
  }

  Object? _definitions;
  String? _selection;
  bool _disposed = false;
  CourseMeta? get selectedCourse => context.selectedCourse;
  CurriculumProfile? get activeProfile => context.activeProfile;
  List<CurriculumProfile> get profiles => context.profiles;
  List<Subject> get catalogSubjects => context.catalogSubjects;
  CourseDetails? get courseDetails => context.courseDetails;
  bool get loading => context.loading;
  String get _course => context.courseId;
  String get _profile => activeProfile?.id ?? context.selectedProfile;
  List<Discipline> get schedule => plan.selected;
  Set<String> get completedDisciplines => completions.completedFor(_course);
  bool isCompleted(Object item) => completions.isCompleted(_course, item);
  dynamic _json(String? value) => personalProgress.decode(value);
  Future<void> confirmPersistence() => personalProgress.flush();
  Future<void> retryPersistence() => personalProgress.retry();
  Future<void> selectProfile(String value) => context.selectProfile(value);

  void _migrateCompletions() => completions.migrate(_course, [
    ...profiles.expand((p) => p.subjects),
    ...catalogSubjects,
    ...context.offerings.map((d) => Subject.fromJson(d.toJson())),
  ]);

  void _contextChanged() {
    final selection =
        '${context.selectedCourse?.id}:${context.selectedProfile}';
    if (!identical(_definitions, courseDetails) || _selection != selection) {
      _definitions = courseDetails;
      _selection = selection;
      _hydrateSubjects();
      if (profiles.isNotEmpty) _migrateCompletions();
    }
    notifyListeners();
  }

  void _planChanged() {
    _scheduleIds = null;
    _scheduleCodes = null;
    notifyListeners();
  }

  void _completionsChanged() {
    _subjects = _subjects.map((s) {
      final completed = isCompleted(s);
      if (!completed && s.raw['status'] != 'concluido') return s;
      return Subject.fromJson({
        ...s.toJson(),
        'status': completed ? 'concluido' : 'pendente',
        'grade': completed ? textOf(s.raw['grade']) : '',
      }, profile: s.profile);
    }).toList();
    _persistProgress();
    notifyListeners();
  }

  void setCompleted(Object subject, bool completed) {
    if (selectedCourse == null) return;
    _migrateCompletions();
    completions.setCompleted(_course, subject, completed);
  }

  void _hydrateSubjects({List<JsonMap>? importedSubjects}) {
    _subjects = personalProgress.restore(
      _course,
      activeProfile,
      importedSubjects: importedSubjects,
    );
  }

  String subjectStatus(Subject s) {
    _indexSubjects();
    _indexSchedule();
    s = _byIdentity![(s.id, s.profile)] ?? s;
    if (isCompleted(s)) return 'concluido';
    if (_scheduleIds!.contains(s.id) ||
        (s.displayCode?.isNotEmpty == true &&
            _scheduleCodes!.contains(s.displayCode!.toUpperCase()))) {
      return 'cursando';
    }
    return s.raw['status'] == 'cursando' ? 'cursando' : 'pendente';
  }

  void setSubjectStatus(Subject s, String status) {
    return _edit(() {
      if (!['pendente', 'cursando', 'concluido'].contains(status)) return;
      setCompleted(s, status == 'concluido');
      _subjects = _subjects
          .map(
            (e) => e.id == s.id
                ? Subject.fromJson({
                    ...e.toJson(),
                    'status': status,
                  }, profile: e.profile)
                : e,
          )
          .toList();
      _persistProgress();
      notifyListeners();
    });
  }

  String grade(Subject s) {
    _indexSubjects();
    return textOf(_byId![s.id]?.raw['grade'] ?? s.raw['grade']);
  }

  void setGrade(Subject s, String value) {
    final grade = AcademicGrades.normalize(value);
    if (grade == null) return;
    _subjects = _subjects
        .map(
          (e) => e.id == s.id
              ? Subject.fromJson({
                  ...e.toJson(),
                  'grade': grade,
                }, profile: e.profile)
              : e,
        )
        .toList();
    _persistProgress();
    notifyListeners();
  }

  List<Subject> missingPrerequisites(Subject s) {
    _indexSubjects();
    return s.prereqs
        .map((key) => _byLookup![normalized(key)]?.firstOrNull)
        .whereType<Subject>()
        .where((subject) => !isCompleted(subject))
        .toList();
  }

  bool isUnlocked(Subject s) {
    _indexSubjects();
    return s.prereqs.every(
      (key) => _byLookup![normalized(key)]?.any(isCompleted) == true,
    );
  }

  void _persistProgress() {
    if (_editDepth > 0) {
      _pendingProgress = true;
      return;
    }
    if (selectedCourse != null && activeProfile != null) {
      personalProgress.save(_course, _profile, _subjects, isCompleted);
    }
  }

  double get acexHours => personalProgress.hours(_course, _profile, 'acex');
  double get accHours => personalProgress.hours(_course, _profile, 'acc');
  void setHours({double? acex, double? acc}) {
    personalProgress.setHours(_course, _profile, acex: acex, acc: acc);
    notifyListeners();
  }

  bool _selectionAssigned(ElectiveSelection selection, {String? excluding}) =>
      ElectiveAssignments.isAssigned(
        _subjects,
        selection,
        excluding: excluding,
      );

  String? setElective(
    Subject slot, {
    required String name,
    required double hours,
    String? code,
    String? desc,
    String? subjectId,
  }) {
    return _edit(() {
      if (name.trim().isEmpty || !hours.isFinite || hours <= 0) {
        return 'Informe um nome e uma carga horária positiva.';
      }
      final selection = ElectiveSelection(
        name: name.trim(),
        hours: hours,
        code: code,
        desc: desc,
        subjectId: subjectId,
        source: subjectId != null || code?.isNotEmpty == true
            ? 'catalog'
            : 'manual',
      );
      if (_selectionAssigned(selection, excluding: slot.id)) {
        return 'Esta disciplina já está utilizada em outro cartão da matriz.';
      }
      if (!slot.isGenericElective && !slot.additionalElective) {
        return 'Selecione um cartão de optativa.';
      }
      final wasComplete = isCompleted(slot);
      if (wasComplete) setCompleted(slot, false);
      _subjects = _subjects
          .map(
            (s) => s.id == slot.id
                ? Subject.fromJson({
                    ...s.toJson(),
                    'electiveSelection': selection.toJson(),
                  }, profile: s.profile)
                : s,
          )
          .toList();
      if (wasComplete) {
        setCompleted(_subjects.firstWhere((s) => s.id == slot.id), true);
      }
      _persistProgress();
      notifyListeners();
      return null;
    });
  }

  String? addElective({
    required String name,
    required double hours,
    String? code,
    String? desc,
  }) {
    if (name.trim().isEmpty || !hours.isFinite || hours <= 0) {
      return 'Informe um nome e uma carga horária positiva.';
    }
    final selection = ElectiveSelection(
      name: name.trim(),
      hours: hours,
      code: code,
      desc: desc,
      source: code?.isNotEmpty == true ? 'catalog' : 'manual',
    );
    if (_selectionAssigned(selection)) {
      return 'Esta disciplina já está utilizada em outro cartão da matriz.';
    }
    final maxPeriod = subjects.fold<int>(
      1,
      (max, s) => math.max(max, s.period ?? 0),
    );
    _subjects = [
      ..._subjects,
      Subject.fromJson({
        'id': 'personal_opt_${DateTime.now().microsecondsSinceEpoch}',
        'name': 'Optativa adicional',
        'type': 'optativa',
        'period': maxPeriod,
        'additionalElective': true,
        'electiveSelection': selection.toJson(),
      }, profile: _profile),
    ];
    _persistProgress();
    notifyListeners();
    return null;
  }

  void removeElective(Subject subject) {
    return _edit(() {
      if (!subject.isGenericElective && !subject.additionalElective) return;
      setCompleted(subject, false);
      if (subject.additionalElective) {
        _subjects = _subjects.where((entry) => entry.id != subject.id).toList();
      } else {
        _subjects = _subjects.map((s) {
          if (s.id != subject.id) return s;
          final raw = s.toJson()..remove('electiveSelection');
          return Subject.fromJson(raw, profile: s.profile);
        }).toList();
      }
      _persistProgress();
      notifyListeners();
    });
  }

  List<Subject> get countedSubjects {
    final assigned = subjects
        .where((s) => s.electiveSelection?.source == 'catalog')
        .map((s) => s.electiveSelection!.identity)
        .toSet();
    final seen = <String>{};
    return subjects.where((s) {
      final selection = s.electiveSelection;
      final named =
          s.isElective && !s.isGenericElective && !s.additionalElective;
      final identity = selection?.source == 'catalog'
          ? selection!.identity
          : selection == null && named
          ? (s.code?.isNotEmpty == true
                ? 'code:${normalized(s.code!)}'
                : 'name:${normalized(s.name)}')
          : 'slot:${s.id}';
      if (selection == null && named && assigned.contains(identity)) {
        return false;
      }
      return seen.add(identity);
    }).toList();
  }

  MatrixProgress get progress => AcademicProgressCalculator.calculate(
    courseId: _course,
    profile: activeProfile,
    counted: countedSubjects,
    isCompleted: isCompleted,
    acexHours: acexHours,
    accHours: accHours,
  );

  String exportProfileProgress() => jsonEncode({
    'course': _course,
    'profileId': _profile,
    'profileName': activeProfile?.name ?? '',
    'subjects': _subjects
        .map(
          (s) => {
            ...s.toJson(),
            'status': isCompleted(s)
                ? 'concluido'
                : s.raw['status'] == 'cursando'
                ? 'cursando'
                : 'pendente',
            'grade': grade(s),
          },
        )
        .toList(),
    'statuses': {
      for (final s in _subjects)
        s.id: isCompleted(s)
            ? 'concluido'
            : s.raw['status'] == 'cursando'
            ? 'cursando'
            : 'pendente',
    },
    'acexHours': acexHours,
    'accHours': accHours,
  });

  Future<bool> importProfileProgress(String value) async {
    final data = _json(value);
    if (selectedCourse == null ||
        activeProfile == null ||
        data is! Map ||
        data['course'] is! String ||
        data['profileId'] is! String ||
        normalized(data['course']) != normalized(_course) ||
        normalized(data['profileId']) != normalized(_profile) ||
        data['subjects'] is! List) {
      return false;
    }
    if (data['statuses'] != null && data['statuses'] is! Map) return false;
    if (data['statuses'] is Map &&
        (data['statuses'] as Map).entries.any(
          (entry) =>
              entry.key is! String ||
              !['pendente', 'cursando', 'concluido'].contains(entry.value),
        )) {
      return false;
    }
    final rows = <JsonMap>[];
    for (final value in data['subjects']) {
      if (value is! Map ||
          value['id'] is! String ||
          (value['id'] as String).trim().isEmpty) {
        return false;
      }
      final row = asMap(value);
      if (row['status'] != null &&
          !['pendente', 'cursando', 'concluido'].contains(row['status'])) {
        return false;
      }
      if (row['grade'] != null &&
          (row['grade'] is! String ||
              AcademicGrades.normalize(row['grade']) == null)) {
        return false;
      }
      rows.add(row);
    }
    for (final key in ['acexHours', 'accHours']) {
      final hours = data[key];
      if (hours != null && (hours is! num || !hours.isFinite || hours < 0)) {
        return false;
      }
    }
    final previous = List<Subject>.of(_subjects);
    _hydrateSubjects(importedSubjects: rows);
    _replaceProfileCompletions(previous);
    if (data['acexHours'] != null || data['accHours'] != null) {
      setHours(
        acex: (data['acexHours'] as num?)?.toDouble(),
        acc: (data['accHours'] as num?)?.toDouble(),
      );
    }
    _persistProgress();
    await personalProgress.flush();
    if (_disposed) return false;
    notifyListeners();
    return true;
  }

  Future<void> resetProfileProgress() async {
    if (selectedCourse == null || activeProfile == null) return;
    final previous = List<Subject>.of(_subjects);
    _hydrateSubjects(importedSubjects: []);
    _replaceProfileCompletions(previous);
    setHours(acex: 0, acc: 0);
    _persistProgress();
    await personalProgress.flush();
    if (!_disposed) notifyListeners();
  }

  void _replaceProfileCompletions(List<Subject> previous) {
    _migrateCompletions();
    final identities = [
      ...previous,
      ...countedSubjects,
    ].map(CompletionIdentity.of).toSet();
    final next = completedDisciplines
        .where((entry) => !identities.contains(entry))
        .toSet();
    next.addAll(
      countedSubjects
          .where((s) => s.raw['status'] == 'concluido')
          .map(CompletionIdentity.of),
    );
    completions.replace(_course, next);
  }

  @override
  void dispose() {
    _disposed = true;
    context.removeListener(_contextChanged);
    completions.removeListener(_completionsChanged);
    plan.removeListener(_planChanged);
    super.dispose();
  }
}
