import 'package:flutter/foundation.dart';

import 'models.dart';
import '../data/repositories/academic/academic_data_repository.dart';
import '../data/repositories/personal/personal_storage_repository.dart';
import '../domain/entities/course_details.dart';
import 'exceptions/app_exception.dart';

/// Shared academic selection and published definitions. Personal edits and theme
/// have their own owners and do not notify this context.
class AcademicContext extends ChangeNotifier {
  AcademicContext(this.data, this.storage);
  final AcademicDataRepository data;
  final PersonalStorageRepository storage;
  List<CourseMeta> courses = [];
  CourseMeta? selectedCourse;
  String selectedSemester = '2026.2', selectedProfile = 'all';
  List<CurriculumProfile> profiles = [];
  List<Discipline> offerings = [];
  List<Subject> catalogSubjects = [];
  CourseDetails? courseDetails;
  AppException? loadFailure;
  bool loading = false, offline = false;
  String? error;
  bool _disposed = false;
  @protected
  bool get isDisposed => _disposed;
  int _requestVersion = 0;
  String get courseId => selectedCourse?.id ?? 'bcc';
  String? _read(String key) => storage.read(key);
  void _write(String key, String? value) => storage.write(key, value);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> initialize() async {
    if (_disposed) return;
    loading = true;
    notifyListeners();
    selectedSemester = _read('selectedSemester') ?? '2026.2';
    await _loadCourses();
    if (_disposed) return;
    final courseId = _read('selectedCourse');
    selectedCourse = courses.where((e) => e.id == courseId).firstOrNull;
    if (selectedCourse != null) {
      await selectCourse(selectedCourse);
    } else {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCourses() async {
    final result = await data.list();
    if (_disposed) return;
    courses = result.data;
    offline = result.offline;
    error = result.error;
  }

  Future<void> refresh() async {
    await _loadCourses();
    if (_disposed) return;
    if (selectedCourse != null) {
      selectedCourse =
          courses.where((e) => e.id == selectedCourse!.id).firstOrNull ??
          selectedCourse;
      await _loadCourse();
    } else {
      notifyListeners();
    }
  }

  Future<void> selectCourse(CourseMeta? course) async {
    ++_requestVersion;
    selectedCourse = course;
    offerings = [];
    profiles = [];
    catalogSubjects = [];
    courseDetails = null;
    error = null;
    loadFailure = null;
    _write('selectedCourse', course?.id);
    if (course == null) {
      loading = false;
      notifyListeners();
      return;
    }
    if (course.visibleSemesters.isNotEmpty &&
        !course.visibleSemesters.contains(selectedSemester)) {
      selectedSemester = course.visibleSemesters.first;
    }
    _write('selectedSemester', selectedSemester);
    selectedProfile = _read('selected_profile_${course.id}') ?? 'all';
    notifyListeners();
    await _loadCourse();
  }

  Future<void> selectSemester(String semester) async {
    final available = selectedCourse?.visibleSemesters ?? [];
    if (available.isNotEmpty && !available.contains(semester)) {
      semester = available.first;
    }
    if (semester == selectedSemester) return;
    selectedSemester = semester;
    _write('selectedSemester', semester);
    offerings = [];
    notifyListeners();
    await _loadCourse();
  }

  Future<void> selectProfile(String profile) async {
    selectedProfile = _normalizeProfile(profile);
    if (selectedCourse != null) {
      _write('selected_profile_${selectedCourse!.id}', selectedProfile);
    }
    _write('saved_selectedProfile', selectedProfile);
    notifyListeners();
  }

  Future<void> _loadCourse() async {
    final course = selectedCourse;
    if (course == null) return;
    final version = ++_requestVersion;
    final semester = selectedSemester;
    loading = true;
    error = null;
    loadFailure = null;
    notifyListeners();
    final result = await data.get(course, semester);
    if (_disposed || version != _requestVersion) return;
    final read = result.getOrNull();
    if (read == null) {
      offline = true;
      final failure = result.exceptionOrNull();
      loadFailure = failure is AppException ? failure : null;
      loading = false;
      error = '$failure';
      notifyListeners();
      return;
    }
    offline = read.offline;
    error = read.error;
    loadFailure = read.failure;
    final details = read.data;
    courseDetails = details;
    if (details.semester != selectedSemester) {
      selectedSemester = details.semester;
      _write('selectedSemester', selectedSemester);
    }
    profiles = List.of(details.profiles);
    offerings = List.of(details.offerings);
    catalogSubjects = List.of(details.catalog);
    selectedProfile = _normalizeProfile(selectedProfile);
    _write('selected_profile_$courseId', selectedProfile);
    loading = false;
    notifyListeners();
  }

  String _normalizeProfile(String value) {
    final profile = value == 'todos' ? 'all' : value;
    if (profile == 'all' ||
        profiles.any((p) => p.id == profile) ||
        offerings.any((d) => d.profile == profile) ||
        catalogSubjects.any((s) => s.profile == profile)) {
      return profile;
    }
    return 'all';
  }

  CurriculumProfile? get activeProfile {
    final selected = profiles.where((p) => p.id == selectedProfile).firstOrNull;
    if (selected != null) return selected;
    final legacy =
        _read('matrix_version_$courseId') ??
        (courseId == 'bcc' ? _read('bcc_matrix_version') : null);
    final legacyId = legacy == 'antiga'
        ? 'BCC02'
        : legacy != null
        ? 'BCC03'
        : '';
    final activeId = courseDetails?.activeProfileId;
    return profiles.where((p) => p.id == legacyId).firstOrNull ??
        profiles.where((p) => p.id == activeId).firstOrNull ??
        profiles.firstOrNull;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_requestVersion;
    super.dispose();
  }
}
