import 'package:flutter/foundation.dart';

import '../../../core/academic_context.dart';
import '../../../core/models.dart';
import '../../../domain/entities/course_details.dart';
import '../../../domain/academic_rules.dart';
import '../../../data/repositories/personal/completion_repository.dart';
import '../../../data/repositories/personal/schedule_plan_repository.dart';

class ScheduleViewModel extends ChangeNotifier {
  ScheduleViewModel(this.context, this.completions, this.plan) {
    context.addListener(_contextChanged);
    completions.addListener(_completionsChanged);
    plan.addListener(_planChanged);
  }
  final AcademicContext context;
  final CompletionRepository completions;
  final SchedulePlanRepository plan;
  Object? _definitions;
  int _sourceUpdateDepth = 0;

  // Reconciliation can synchronously trigger plan/completion listeners.
  // Publish once, after all sources represent the same academic selection.
  void _updateSources(VoidCallback update) {
    _sourceUpdateDepth++;
    try {
      update();
    } finally {
      _sourceUpdateDepth--;
      if (_sourceUpdateDepth == 0) notifyListeners();
    }
  }

  List<Discipline>? _indexedOfferings;
  List<({Discipline offering, String text, bool common})> _searchIndex = [];
  List<String> _offeringProfiles = const [];
  List<int> _offeringPeriods = const [];
  bool _hasElectives = false;
  (String, int?, String)? _filterKey;
  List<Discipline> _filtered = const [];

  void _indexOfferings() {
    final source = offerings;
    // Legacy callers can still edit the context list in place.
    if (listEquals(_indexedOfferings, source)) return;
    _indexedOfferings = List.unmodifiable(source);
    final profiles = <String>{};
    final periods = <int>{};
    _hasElectives = false;
    _searchIndex = source.map((d) {
      final profile = normalized(d.profile ?? '');
      if (d.profile != null && d.profile!.isNotEmpty && profile != 'optativa') {
        profiles.add(d.profile!);
      }
      if (d.period != null && d.period! > 0) periods.add(d.period!);
      if (d.period == 0) _hasElectives = true;
      return (
        offering: d,
        text: normalized(
          '${d.name} ${d.professor ?? ''} ${d.code ?? ''} ${d.profile ?? ''}',
        ),
        common:
            d.period == 0 ||
            d.profile == null ||
            d.profile!.isEmpty ||
            profile == 'optativa' ||
            profile == 'sem perfil',
      );
    }).toList();
    _offeringProfiles = List.unmodifiable(profiles.toList()..sort());
    _offeringPeriods = List.unmodifiable(periods.toList()..sort());
    _filterKey = null;
  }

  List<String> get offeringProfiles {
    _indexOfferings();
    return _offeringProfiles;
  }

  List<int> get offeringPeriods {
    _indexOfferings();
    return _offeringPeriods;
  }

  bool get hasElectives {
    _indexOfferings();
    return _hasElectives;
  }

  CourseMeta? get selectedCourse => context.selectedCourse;
  String get selectedSemester => context.selectedSemester;
  String get selectedProfile => context.selectedProfile;
  List<Discipline> get offerings => context.offerings;
  List<Subject> get catalogSubjects => context.catalogSubjects;
  List<Subject> get detailSubjects => [
    ...?context.activeProfile?.subjects,
    ...catalogSubjects,
    ...offerings.map((offering) => Subject.fromJson(offering.toJson())),
  ];
  CourseDetails? get courseDetails => context.courseDetails;
  List<Discipline> get schedule => plan.selected;
  bool get loading => context.loading;
  Future<void> confirmPersistence() => plan.flush();
  Future<void> retryPersistence() => plan.retry();
  Future<void> selectProfile(String value) => context.selectProfile(value);
  bool isCompleted(Object item) =>
      completions.isCompleted(context.courseId, item);
  void setCompleted(Object item, bool value) {
    if (selectedCourse == null) return;
    completions.migrate(context.courseId, [
      ...context.profiles.expand((p) => p.subjects),
      ...context.catalogSubjects,
      ...offerings.map((d) => Subject.fromJson(d.toJson())),
    ]);
    completions.setCompleted(context.courseId, item, value);
  }

  Discipline? conflictWith(Discipline item) =>
      ScheduleConflicts.find(schedule, item);
  String? conflictFor(Discipline item) => conflictWith(item)?.name;

  void _contextChanged() => _updateSources(() {
    if (plan.course != selectedCourse?.id ||
        plan.semester != selectedSemester ||
        (!identical(_definitions, context.courseDetails) &&
            context.courseDetails == null)) {
      plan.restore(selectedCourse?.id, selectedSemester);
    }
    if (!identical(_definitions, context.courseDetails)) {
      _definitions = context.courseDetails;
      if (offerings.isNotEmpty) {
        final byId = {for (final d in offerings) d.id: d};
        final byCode = {
          for (final d in offerings)
            if (d.code != null) d.code!: d,
        };
        final next = schedule
            .map((d) => byId[d.id] ?? byCode[d.code])
            .whereType<Discipline>()
            .where((d) => !isCompleted(d))
            .toList();
        if (!listEquals(next, schedule)) plan.replace(next);
      }
    }
    _completionsChanged();
  });

  void _completionsChanged() {
    if (plan.course != selectedCourse?.id ||
        plan.semester != selectedSemester) {
      return;
    }
    _updateSources(() {
      final next = schedule.where((d) => !isCompleted(d)).toList();
      if (next.length != schedule.length) plan.replace(next);
    });
  }

  void _planChanged() {
    if (_sourceUpdateDepth == 0) notifyListeners();
  }

  String? toggleDiscipline(Discipline discipline) {
    if (isCompleted(discipline)) return 'Esta disciplina já foi concluída.';
    final next = schedule.toList();
    if (next.any((e) => e.id == discipline.id)) {
      next.removeWhere((e) => e.id == discipline.id);
    } else {
      final conflict = conflictFor(discipline);
      if (conflict != null) {
        return 'Conflito: ${discipline.name} choca com $conflict.';
      }
      next.add(discipline);
    }
    plan.replace(next);
    return null;
  }

  Future<void> clearSchedule() => plan.replace([]);
  List<Discipline> filteredOfferings({
    String query = '',
    int? period,
    String? profile,
  }) {
    final q = normalized(query);
    final p = profile ?? selectedProfile;
    _indexOfferings();
    final key = (q, q.isEmpty ? period : null, p);
    if (_filterKey == key) return _filtered;
    _filterKey = key;
    return _filtered = List.unmodifiable(
      _searchIndex
          .where((entry) {
            final d = entry.offering;
            return (p == 'all' || entry.common || d.profile == p) &&
                (q.isNotEmpty
                    ? entry.text.contains(q)
                    : period == null || d.period == period);
          })
          .map((entry) => entry.offering),
    );
  }

  @override
  void dispose() {
    context.removeListener(_contextChanged);
    completions.removeListener(_completionsChanged);
    plan.removeListener(_planChanged);
    super.dispose();
  }
}
