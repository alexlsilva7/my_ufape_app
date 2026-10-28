import 'package:flutter/material.dart';

import '../domain/entities/course_details.dart';
import 'exceptions/app_exception.dart';

import '../app/app_repositories.dart';
import '../data/repositories/academic/academic_data_repository.dart';
import '../data/repositories/personal/personal_storage_repository.dart';
import '../data/repositories/personal/completion_repository.dart';
import '../data/repositories/personal/schedule_plan_repository.dart';
import '../features/academic/matrix/matrix_view_model.dart';
import '../features/academic/schedule/schedule_view_model.dart';
import '../features/academic/catalog/catalog_view_model.dart';
import '../features/feedback/feedback_view_model.dart';
import '../features/calendar/calendar_view_model.dart';
import '../features/home/home_view_model.dart';
import '../features/settings/settings_view_model.dart';
import 'academic_context.dart';
import 'models.dart';

export 'models.dart';
export '../data/repositories/personal/backup_repository.dart'
    show isBackupStorageKey;

/// Root application state and resource owner. Only academic context changes
/// notify this object; feature changes use their respective ViewModels.
class AppState extends ChangeNotifier {
  AppState.injected({
    required this.repositories,
    required this.context,
    required this.storage,
    required this.data,
    required this.completions,
    required this.plan,
    required this.matrix,
    required this.timetable,
    required this.catalog,
    required this.calendar,
    required this.settings,
    required this.home,
    required this.feedback,
    required this.releaseDependencies,
  }) {
    context.addListener(_contextChanged);
  }
  final AppRepositories repositories;
  final AcademicContext context;
  final PersonalStorageRepository storage;
  final AcademicDataRepository data;
  final CompletionRepository completions;
  final SchedulePlanRepository plan;
  final MatrixViewModel matrix;
  final ScheduleViewModel timetable;
  final CatalogViewModel catalog;
  final CalendarViewModel calendar;
  final SettingsViewModel settings;
  final HomeViewModel home;
  final FeedbackViewModel feedback;
  final void Function() releaseDependencies;
  bool _disposed = false;
  void _contextChanged() {
    if (!_disposed) notifyListeners();
  }

  List<CourseMeta> get courses => context.courses;
  CourseMeta? get selectedCourse => context.selectedCourse;
  set selectedCourse(CourseMeta? value) => context.selectedCourse = value;
  String get selectedSemester => context.selectedSemester;
  set selectedSemester(String value) => context.selectedSemester = value;
  String get selectedProfile => context.selectedProfile;
  set selectedProfile(String value) => context.selectedProfile = value;
  List<CurriculumProfile> get profiles => context.profiles;
  List<Discipline> get offerings => context.offerings;
  set offerings(List<Discipline> value) => context.offerings = value;
  List<Subject> get catalogSubjects => context.catalogSubjects;
  CourseDetails? get courseDetails => context.courseDetails;
  AppException? get loadFailure => context.loadFailure;
  bool get loading => context.loading;
  bool get offline => context.offline;
  set offline(bool value) => context.offline = value;
  String? get error => context.error;
  String get courseId => context.courseId;
  CurriculumProfile? get activeProfile => context.activeProfile;
  Future<void> refresh() => context.refresh();
  Future<void> selectCourse(CourseMeta? course) => context.selectCourse(course);
  Future<void> selectSemester(String value) => context.selectSemester(value);
  Future<void> selectProfile(String value) => context.selectProfile(value);
  String get apiBaseUrl => settings.apiBaseUrl;
  String get dataSourceLabel => settings.dataSourceLabel;
  ThemeMode get themeMode => settings.themeMode;
  void cycleTheme() => settings.cycleTheme();
  void setThemeMode(ThemeMode mode) => settings.setThemeMode(mode);
  Future<void> setApiBaseUrl(String value) => settings.setApiBaseUrl(value);
  String exportBackup() => settings.exportBackup();
  Future<bool> importBackup(String value) => settings.importBackup(value);

  List<Subject> get subjects => matrix.subjects;
  List<Discipline> get schedule => timetable.schedule;
  Set<String> get completedDisciplines => matrix.completedDisciplines;
  bool isCompleted(Object item) => matrix.isCompleted(item);
  void setCompleted(Object item, bool value) =>
      matrix.setCompleted(item, value);
  String subjectStatus(Subject subject) => matrix.subjectStatus(subject);
  void setSubjectStatus(Subject subject, String value) =>
      matrix.setSubjectStatus(subject, value);
  String grade(Subject subject) => matrix.grade(subject);
  void setGrade(Subject subject, String value) =>
      matrix.setGrade(subject, value);
  List<Subject> missingPrerequisites(Subject subject) =>
      matrix.missingPrerequisites(subject);
  bool isUnlocked(Subject subject) => matrix.isUnlocked(subject);
  String? conflictFor(Discipline item) => timetable.conflictFor(item);
  String? toggleDiscipline(Discipline item) => timetable.toggleDiscipline(item);
  Future<void> clearSchedule() => timetable.clearSchedule();
  List<Discipline> filteredOfferings({
    String query = '',
    int? period,
    String? profile,
  }) => timetable.filteredOfferings(
    query: query,
    period: period,
    profile: profile,
  );
  double get acexHours => matrix.acexHours;
  double get accHours => matrix.accHours;
  void setHours({double? acex, double? acc}) =>
      matrix.setHours(acex: acex, acc: acc);
  String? setElective(
    Subject slot, {
    required String name,
    required double hours,
    String? code,
    String? desc,
    String? subjectId,
  }) => matrix.setElective(
    slot,
    name: name,
    hours: hours,
    code: code,
    desc: desc,
    subjectId: subjectId,
  );
  String? addElective({
    required String name,
    required double hours,
    String? code,
    String? desc,
  }) => matrix.addElective(name: name, hours: hours, code: code, desc: desc);
  void removeElective(Subject subject) => matrix.removeElective(subject);
  List<Subject> get countedSubjects => matrix.countedSubjects;
  MatrixProgress get progress => matrix.progress;
  String exportProfileProgress() => matrix.exportProfileProgress();
  Future<bool> importProfileProgress(String value) =>
      matrix.importProfileProgress(value);
  Future<void> resetProfileProgress() => matrix.resetProfileProgress();

  Future<void> initialize() async {
    await settings.initialize();
    if (_disposed) return;
    await context.initialize();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    context.removeListener(_contextChanged);
    home.dispose();
    catalog.dispose();
    calendar.dispose();
    timetable.dispose();
    matrix.dispose();
    settings.dispose();
    completions.dispose();
    plan.dispose();
    storage.dispose();
    context.dispose();
    repositories.dispose();
    releaseDependencies();
    super.dispose();
  }
}
