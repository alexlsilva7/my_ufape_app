import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_repositories.dart';

import 'api_client.dart';
import 'data_source.dart';
import 'models.dart';
export 'models.dart';

class AppState extends ChangeNotifier {
  final AppRepositories repositories;
  String get apiBaseUrl => repositories.apiBaseUrl;
  String get dataSourceLabel => repositories.dataSourceLabel;
  String get _cachePrefix => repositories.source == DataSource.api
      ? 'flutter_cache'
      : 'flutter_cache_${repositories.source.name}';
  final Future<String> Function(String) _loadAsset;
  final Map<String, String> _storage = {};
  List<CourseMeta> courses = [];
  CourseMeta? selectedCourse;
  String selectedSemester = '2026.1', selectedProfile = 'all';
  List<CurriculumProfile> profiles = [];
  List<Discipline> offerings = [], schedule = [];
  List<Subject> catalogSubjects = [];
  List<Subject> _subjects = [];
  List<Subject> get subjects => List.unmodifiable(_subjects);
  JsonMap courseDetails = {};
  bool loading = false, offline = false;
  String? error;
  ThemeMode themeMode = ThemeMode.light;
  int _requestVersion = 0;
  bool _disposed = false;
  bool _storageReady = false;
  AppState({
    AcademicApi? api,
    AppRepositories? repositories,
    Future<String> Function(String)? assetLoader,
  }) : assert(api == null || repositories == null),
       repositories =
           repositories ?? AppRepositories(api: api, assetLoader: assetLoader),
       _loadAsset = assetLoader ?? rootBundle.loadString;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  String? _read(String key) => _storage[key];
  void _write(String key, String? value) {
    if (value == null) {
      _storage.remove(key);
      if (_storageReady) unawaited(repositories.localStorage.remove(key));
    } else {
      _storage[key] = value;
      if (_storageReady) unawaited(repositories.localStorage.write(key, value));
    }
  }

  dynamic _json(String? text) {
    try {
      return text == null ? null : jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    loading = true;
    notifyListeners();
    _storage.addAll(await repositories.localStorage.readAll());
    _storageReady = true;
    final configured = _read('flutter_api_base_url');
    if (repositories.source == DataSource.api &&
        configured != null &&
        configured.isNotEmpty) {
      repositories.setApiBaseUrl(configured);
    }
    themeMode = switch (_read('themePreference')) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    selectedSemester = _read('selectedSemester') ?? '2026.1';
    await _loadCourses();
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
    dynamic result;
    try {
      result = await repositories.courses.list();
      _write('${_cachePrefix}_courses', jsonEncode(result));
      offline = false;
      error = null;
    } catch (failure) {
      result = _json(_read('${_cachePrefix}_courses'));
      offline = true;
      if (repositories.source != DataSource.api) error = '$failure';
    }
    result ??= _json(await _asset('assets/data/courses.json'));
    final list = result is List ? result : asMap(result)['courses'];
    courses = asList(list)
        .map((e) => CourseMeta.fromJson(asMap(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
    if (courses.isEmpty) error = 'Não foi possível carregar os cursos. Verifique a conexão e o endereço do servidor.';
  }

  Future<String?> _asset(String path) async {
    try {
      return await _loadAsset(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> setApiBaseUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('Informe um endereço HTTP ou HTTPS válido.');
    }
    repositories.setApiBaseUrl(url.trim());
    _write('flutter_api_base_url', url.trim());
    await refresh();
  }

  void cycleTheme() {
    themeMode = switch (themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    _write('themePreference', themeMode.name);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _write('themePreference', mode.name);
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadCourses();
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
    schedule = [];
    profiles = [];
    _subjects = [];
    catalogSubjects = [];
    courseDetails = {};
    error = null;
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
    _restoreSchedule();
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
    _restoreSchedule();
    notifyListeners();
    await _loadCourse();
  }

  Future<void> selectProfile(String profile) async {
    selectedProfile = _normalizeProfile(profile);
    if (selectedCourse != null) {
      _write('selected_profile_${selectedCourse!.id}', selectedProfile);
    }
    _write('saved_selectedProfile', selectedProfile);
    _hydrateSubjects();
    notifyListeners();
  }

  Future<void> _loadCourse() async {
    final course = selectedCourse;
    if (course == null) return;
    final version = ++_requestVersion;
    final semester = selectedSemester;
    final cacheKey = '${_cachePrefix}_${course.id}_$semester';
    loading = true;
    error = null;
    notifyListeners();
    dynamic data;
    try {
      data = await repositories.courses.get(
        course.id,
        semester: semester,
        academicOnly: true,
      );
      if (version != _requestVersion) return;
      offline = false;
      _write(cacheKey, jsonEncode(data));
    } catch (failure) {
      if (version != _requestVersion) return;
      data = _json(_read(cacheKey));
      offline = true;
      if (repositories.source != DataSource.api) error = '$failure';
    }
    data ??= _json(await _asset('assets/data/${course.id}_$semester.json'));
    data ??= _json(await _asset('assets/data/${course.id}.json'));
    if (version != _requestVersion) return;
    if (data == null) {
      loading = false;
      error = 'Dados indisponíveis para este curso. Verifique o servidor e tente novamente.';
      notifyListeners();
      return;
    }
    courseDetails = asMap(data);
    final embeddedSchedules = asMap(courseDetails['schedules']);
    if (!courseDetails.containsKey('schedule') &&
        embeddedSchedules.isNotEmpty) {
      final semesters = embeddedSchedules.keys.toList()..sort();
      final courseMetadata = asMap(courseDetails['course']);
      final preferred =
          asList(courseMetadata['visibleSemesters']).firstOrNull ??
          asList(courseMetadata['semesters']).firstOrNull;
      final semester = embeddedSchedules.containsKey(selectedSemester)
          ? selectedSemester
          : embeddedSchedules.containsKey(preferred)
          ? preferred.toString()
          : semesters.last;
      final metadata = asMap(
        asMap(courseDetails['scheduleMetadata'])[semester],
      );
      courseDetails = {
        ...courseDetails,
        'schedule': embeddedSchedules[semester],
        'resolvedSemester': semester,
        'scheduleUpdatedAt': metadata['updated_at'],
        'scheduleExtraction': metadata['extraction'],
      };
      if (semester != selectedSemester) {
        selectedSemester = semester;
        _write('selectedSemester', semester);
        _restoreSchedule();
      }
    }
    final resolved = textOf(courseDetails['resolvedSemester']);
    if (!offline && resolved.isNotEmpty && resolved != selectedSemester) {
      selectedSemester = resolved;
      _write('selectedSemester', resolved);
      _restoreSchedule();
    }
    final curriculum = courseDetails['curriculum'];
    final curriculumMap = asMap(curriculum);
    final rawProfiles = asList(curriculumMap['profiles']);
    if (rawProfiles.isNotEmpty) {
      profiles = rawProfiles
          .map((e) => CurriculumProfile.fromJson(asMap(e)))
          .toList();
    } else {
      final tree = asList(curriculumMap['treeSubjects']);
      final rawSubjects = curriculum is List
          ? curriculum
          : tree.isNotEmpty
          ? tree
          : curriculumMap['subjects'];
      profiles = asList(rawSubjects).isEmpty
          ? []
          : [
              CurriculumProfile.fromJson({
                ...curriculumMap,
                'id': course.id,
                'name': course.name,
                'subjects': rawSubjects,
              }),
            ];
    }
    final scheduleData =
        courseDetails['schedule'] ??
        asMap(courseDetails['schedules'])[selectedSemester];
    offerings = asList(
      scheduleData is Map
          ? scheduleData['disciplines'] ?? scheduleData['schedule']
          : scheduleData,
    ).map((e) => Discipline.fromJson(asMap(e))).toList();
    // The official catalogue retains academic types/workloads. Matrix graph
    // nodes carry visual categories and must not appear as duplicate subjects.
    final official = curriculum is List
        ? curriculum
        : asList(curriculumMap['subjects']);
    final catalog = official.isNotEmpty
        ? official.indexed
              .map(
                (entry) => Subject.fromJson(asMap(entry.$2), index: entry.$1),
              )
              .toList()
        : profiles.expand((p) => p.subjects).toList();
    final contents = courseDetails['contents'];
    final contentItems = asList(
      contents is List
          ? contents
          : asMap(contents)['disciplinas'] ?? asMap(contents)['subjects'],
    );
    if (catalog.isEmpty) {
      catalog.addAll(
        contentItems.indexed.map(
          (entry) => Subject.fromJson(asMap(entry.$2), index: entry.$1),
        ),
      );
    }
    final dedup = <String, Subject>{};
    for (final item in catalog) {
      // Two source entries can legitimately carry the same code (the MVET02
      // snapshot does); retain distinct IDs rather than dropping source data.
      final key = '${item.profile ?? ''}:${item.id}';
      final previous = dedup[key];
      if (previous == null || item.desc.length > previous.desc.length) {
        final detail = contentItems
            .map(asMap)
            .where((content) => _matchesContents(item, content))
            .firstOrNull;
        dedup[key] = detail == null
            ? item
            : Subject.fromJson({
                ...item.toJson(),
                if (detail['conteudo_programatico'] != null)
                  'conteudo_programatico': detail['conteudo_programatico'],
                if (item.desc.isEmpty &&
                    (detail['ementa'] ?? detail['desc']) != null)
                  'desc': detail['ementa'] ?? detail['desc'],
              }, profile: item.profile);
      }
    }
    catalogSubjects = dedup.values.toList();
    selectedProfile = _normalizeProfile(selectedProfile);
    _write('selected_profile_$_course', selectedProfile);
    _hydrateSubjects();
    _migrateCompletions();
    _restoreSchedule();
    if (offerings.isNotEmpty) {
      final byId = {for (final d in offerings) d.id: d};
      final byCode = {
        for (final d in offerings)
          if (d.code != null) d.code!: d,
      };
      schedule = schedule
          .map((d) => byId[d.id] ?? byCode[d.code])
          .whereType<Discipline>()
          .where((d) => !isCompleted(d))
          .toList();
      _persistSchedule();
    }
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

  static String _normalizedCode(String? value) => textOf(value)
      .toUpperCase()
      .replaceAllMapped(RegExp(r'([A-Z]+)0+([0-9]+)'), (m) => '${m[1]}${m[2]}');
  static bool _matchesContents(Subject subject, JsonMap content) {
    final code = _normalizedCode(textOf(content['codigo'] ?? content['code']));
    final codes = [
      subject.code,
      ...asList(subject.raw['equivalences'])
          .map((e) => asMap(e)['code']?.toString()),
    ].whereType<String>().map(_normalizedCode);
    return code.isNotEmpty && codes.contains(code) ||
        normalized(textOf(content['nome'] ?? content['name'])) ==
            normalized(subject.name);
  }

  CurriculumProfile? get activeProfile {
    final selected = profiles.where((p) => p.id == selectedProfile).firstOrNull;
    if (selected != null) return selected;
    final legacy =
        _read('matrix_version_$_course') ??
        (_course == 'bcc' ? _read('bcc_matrix_version') : null);
    final legacyId = legacy == 'antiga'
        ? 'BCC02'
        : legacy != null
        ? 'BCC03'
        : '';
    final activeId = textOf(
      asMap(courseDetails['curriculum'])['activeProfileId'],
    );
    return profiles.where((p) => p.id == legacyId).firstOrNull ??
        profiles.where((p) => p.id == activeId).firstOrNull ??
        profiles.firstOrNull;
  }

  String get _course => selectedCourse?.id ?? 'bcc';
  String get _profile => activeProfile?.id ?? selectedProfile;
  String get _progressKey => '${_course}_matriz_progress_$_profile';
  void _hydrateSubjects({List<JsonMap>? importedSubjects}) {
    final profile = activeProfile;
    if (profile == null) {
      _subjects = [];
      return;
    }
    final saved = _json(
      _read(_progressKey) ??
          (_course == 'bcc'
              ? _read(
                  profile.id == 'BCC02'
                      ? 'bcc_matriz_progress_antiga'
                      : 'bcc_matriz_progress',
                )
              : null),
    );
    final savedItems = importedSubjects ?? asList(saved).map(asMap).toList();
    _subjects = profile.subjects.map((s) {
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
        'grade': _validatedGrade(textOf(old?['grade'])) ?? '',
        if (s.isGenericElective && old != null)
          'electiveSelection': old['electiveSelection'],
      }, profile: profile.id);
    }).toList();
    final used = <String>{};
    final fixedElectives = _subjects
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
    _subjects = _subjects.map((s) {
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
          !_subjects.any((e) => e.id == s.id) &&
          !_selectionAssigned(s.electiveSelection!)) {
        _subjects.add(
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
            'grade': _validatedGrade(textOf(raw['grade'])) ?? '',
          }, profile: profile.id),
        );
      }
    }
  }

  String _completionIdentity(Object item) {
    String? code, profile;
    String id;
    if (item is Subject) {
      final selection = item.electiveSelection;
      code = selection?.source == 'catalog' ? selection?.code : item.code;
      id = selection?.source == 'catalog'
          ? selection?.subjectId ?? item.id
          : item.id;
      profile = item.profile;
    } else if (item is Discipline) {
      code = item.code;
      id = item.id;
      profile = item.profile;
    } else {
      return '';
    }
    if (code?.trim().isNotEmpty == true) return code!.trim().toUpperCase();
    return 'id:${Uri.encodeComponent(profile?.trim().isNotEmpty == true ? profile! : 'unassigned')}:${Uri.encodeComponent(id)}';
  }

  String get _completionKey => 'completedDisciplines_${_course.toLowerCase()}';
  Set<String> get completedDisciplines =>
      asList(_json(_read(_completionKey)))
          .whereType<String>()
          .map((e) => e.startsWith('id:') ? e : e.trim().toUpperCase())
          .toSet();
  bool isCompleted(Object item) =>
      completedDisciplines.contains(_completionIdentity(item));
  String _resolveLegacy(String value, String profile) {
    if (value.startsWith('id:')) return value;
    final completionCatalog = [
      ...profiles.expand((p) => p.subjects),
      ...catalogSubjects,
      ...offerings.map((d) => Subject.fromJson(d.toJson())),
    ];
    final matches = completionCatalog
        .where(
          (s) =>
              s.id == value &&
              (profile == 'all' ||
                  profile == 'unassigned' ||
                  s.profile == profile),
        )
        .map(_completionIdentity)
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

  String _resolveScoped(String entry) {
    if (!entry.startsWith('id:')) return entry.trim().toUpperCase();
    final separator = entry.indexOf(':', 3);
    if (separator < 0) return entry;
    try {
      final profile = Uri.decodeComponent(entry.substring(3, separator));
      final id = Uri.decodeComponent(entry.substring(separator + 1));
      return _resolveLegacy(id, profile);
    } catch (_) {
      return entry;
    }
  }

  void _migrateCompletions() {
    if (_read(_completionKey) != null) {
      final resolved = completedDisciplines.map(_resolveScoped).toSet().toList()
        ..sort();
      _write(_completionKey, jsonEncode(resolved));
      return;
    }
    final completed = <String>{};
    for (final entry in _storage.entries.toList()) {
      String? profile;
      if (entry.key.startsWith('${_course}_matriz_progress_')) {
        profile = entry.key.substring('${_course}_matriz_progress_'.length);
      }
      if (_course == 'bcc' && entry.key == 'bcc_matriz_progress') {
        profile = 'BCC03';
      }
      if (_course == 'bcc' && entry.key == 'bcc_matriz_progress_antiga') {
        profile = 'BCC02';
      }
      if (profile != null) {
        for (final raw in asList(_json(entry.value)).map(asMap)) {
          if (raw['status'] == 'concluido') {
            completed.add(
              _resolveScoped(
                _completionIdentity(Subject.fromJson(raw, profile: profile)),
              ),
            );
          }
        }
      }
      final prefix = '${_completionKey}_';
      if (entry.key.startsWith(prefix) ||
          (_course == 'bcc' && entry.key == 'completedDisciplines')) {
        var p = entry.key == 'completedDisciplines'
            ? 'BCC03'
            : entry.key.substring(prefix.length);
        if (p == 'nova') p = 'BCC03';
        if (p == 'antiga') p = 'BCC02';
        for (final value in asList(_json(entry.value)).whereType<String>()) {
          completed.add(_resolveLegacy(value, p));
        }
      }
    }
    _write(_completionKey, jsonEncode(completed.toList()..sort()));
  }

  void setCompleted(Object subject, bool completed) {
    if (selectedCourse == null) return;
    _migrateCompletions();
    final set = completedDisciplines;
    final identity = _completionIdentity(subject);
    if (completed) {
      set.add(identity);
    } else {
      set.remove(identity);
    }
    _write(_completionKey, jsonEncode(set.toList()..sort()));
    if (completed) {
      schedule.removeWhere((e) => _completionIdentity(e) == identity);
      _persistSchedule();
    }
    _subjects = _subjects.map((s) {
      if (_completionIdentity(s) != identity) return s;
      return Subject.fromJson({
        ...s.toJson(),
        'status': completed ? 'concluido' : 'pendente',
        'grade': completed ? textOf(s.raw['grade']) : '',
      }, profile: s.profile);
    }).toList();
    _persistProgress();
    notifyListeners();
  }

  String subjectStatus(Subject s) {
    s =
        _subjects
            .where((e) => e.id == s.id && e.profile == s.profile)
            .firstOrNull ??
        s;
    if (isCompleted(s)) return 'concluido';
    if (schedule.any(
      (e) =>
          e.id == s.id ||
          (s.displayCode?.isNotEmpty == true &&
              e.code?.toUpperCase() == s.displayCode?.toUpperCase()),
    )) {
      return 'cursando';
    }
    return s.raw['status'] == 'cursando' ? 'cursando' : 'pendente';
  }

  void setSubjectStatus(Subject s, String status) {
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
  }

  String grade(Subject s) => textOf(
    _subjects.where((e) => e.id == s.id).firstOrNull?.raw['grade'] ??
        s.raw['grade'],
  );
  void setGrade(Subject s, String value) {
    final grade = _validatedGrade(value);
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

  static String? _validatedGrade(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return '';
    final grade = double.tryParse(normalized);
    return grade != null && grade.isFinite && grade >= 0 && grade <= 10
        ? normalized
        : null;
  }

  List<Subject> missingPrerequisites(Subject s) => s.prereqs
      .map(
        (id) => subjects
            .where(
              (e) => [
                e.id,
                e.code,
                e.name,
              ].any((v) => v != null && normalized(v) == normalized(id)),
            )
            .firstOrNull,
      )
      .whereType<Subject>()
      .where((e) => !isCompleted(e))
      .toList();
  bool isUnlocked(Subject s) => s.prereqs.every(
    (id) => subjects.any(
      (e) =>
          [
            e.id,
            e.code,
            e.name,
          ].any((v) => v != null && normalized(v) == normalized(id)) &&
          isCompleted(e),
    ),
  );
  void _persistProgress() {
    if (selectedCourse == null || activeProfile == null) return;
    final encoded = jsonEncode(
      _subjects
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
    _write(_progressKey, encoded);
    if (_course == 'bcc') {
      _write(
        _profile == 'BCC02'
            ? 'bcc_matriz_progress_antiga'
            : 'bcc_matriz_progress',
        encoded,
      );
    }
  }

  void _restoreSchedule() {
    final raw =
        _read('schedule_${_course}_$selectedSemester') ??
        (selectedSemester == '2026.1' ? _read('schedule_$_course') : null);
    schedule = asList(_json(raw))
        .map((e) => Discipline.fromJson(asMap(e)))
        .where((e) => !isCompleted(e))
        .toList();
  }

  void _persistSchedule() {
    if (selectedCourse == null) return;
    final encoded = jsonEncode(schedule.map((e) => e.toJson()).toList());
    _write('schedule_${_course}_$selectedSemester', encoded);
    if (selectedSemester == '2026.1') _write('schedule_$_course', encoded);
  }

  String? conflictFor(Discipline discipline) {
    for (final other in schedule) {
      if (other.id == discipline.id) continue;
      if (discipline.sessions.any((a) => other.sessions.any(a.overlaps))) {
        return other.name;
      }
    }
    return null;
  }

  String? toggleDiscipline(Discipline discipline) {
    if (isCompleted(discipline)) return 'Esta disciplina já foi concluída.';
    if (schedule.any((e) => e.id == discipline.id)) {
      schedule.removeWhere((e) => e.id == discipline.id);
    } else {
      final conflict = conflictFor(discipline);
      if (conflict != null) {
        return 'Conflito: ${discipline.name} choca com $conflict.';
      }
      schedule.add(discipline);
    }
    _persistSchedule();
    notifyListeners();
    return null;
  }

  void clearSchedule() {
    schedule = [];
    _persistSchedule();
    notifyListeners();
  }

  List<Discipline> filteredOfferings({
    String query = '',
    int? period,
    String? profile,
  }) {
    final q = normalized(query);
    final p = profile ?? selectedProfile;
    return offerings.where((d) {
      final common =
          d.period == 0 ||
          d.profile == null ||
          d.profile!.isEmpty ||
          ['optativa', 'sem perfil'].contains(normalized(d.profile!));
      return (p == 'all' || common || d.profile == p) &&
          (q.isNotEmpty
              ? normalized(
                  '${d.name} ${d.professor ?? ''} ${d.code ?? ''} ${d.profile ?? ''}',
                ).contains(q)
              : period == null || d.period == period);
    }).toList();
  }

  double get acexHours => _hours('acex');
  double get accHours => _hours('acc');
  double _hours(String type) {
    final n = numberOf(
      _read('${_course}_${type}_hours_$_profile') ??
          (_course == 'bcc' && _profile == 'BCC03'
              ? _read('bcc_${type}_hours')
              : null),
    );
    return n.isFinite && n >= 0 ? n : 0;
  }

  void setHours({double? acex, double? acc}) {
    for (final entry in {'acex': acex, 'acc': acc}.entries) {
      if (entry.value == null) continue;
      final value = entry.value!;
      if (!value.isFinite || value < 0) continue;
      _write('${_course}_${entry.key}_hours_$_profile', '$value');
      if (_course == 'bcc' && _profile == 'BCC03') {
        _write('bcc_${entry.key}_hours', '$value');
      }
    }
    notifyListeners();
  }

  bool _selectionAssigned(ElectiveSelection selection, {String? excluding}) =>
      selection.source == 'catalog' &&
      _subjects.any(
        (s) =>
            s.id != excluding &&
            (s.electiveSelection?.identity == selection.identity ||
                s.isElective &&
                    !s.isGenericElective &&
                    (s.period ?? 0) > 0 &&
                    'code:${normalized(s.code ?? '')}' == selection.identity),
      );
  String? setElective(
    Subject slot, {
    required String name,
    required double hours,
    String? code,
    String? desc,
    String? subjectId,
  }) {
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
    _subjects.add(
      Subject.fromJson({
        'id': 'personal_opt_${DateTime.now().microsecondsSinceEpoch}',
        'name': 'Optativa adicional',
        'type': 'optativa',
        'period': maxPeriod,
        'additionalElective': true,
        'electiveSelection': selection.toJson(),
      }, profile: _profile),
    );
    _persistProgress();
    notifyListeners();
    return null;
  }

  void removeElective(Subject subject) {
    if (!subject.isGenericElective && !subject.additionalElective) return;
    setCompleted(subject, false);
    if (subject.additionalElective) {
      _subjects.removeWhere((e) => e.id == subject.id);
    } else {
      _subjects = _subjects.map((s) {
        if (s.id != subject.id) return s;
        final raw = s.toJson()..remove('electiveSelection');
        return Subject.fromJson(raw, profile: s.profile);
      }).toList();
    }
    _persistProgress();
    notifyListeners();
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

  MatrixProgress get progress {
    final p = activeProfile;
    final counted = countedSubjects;
    double mandatory = 0, optative = 0;
    int count = 0;
    for (final s in counted) {
      if (!isCompleted(s)) continue;
      count++;
      if (s.isElective) {
        optative += s.displayHours;
      } else {
        mandatory += s.displayHours;
      }
    }
    final eal =
        _course == 'eal' ||
        _course == 'engenharia-de-alimentos' ||
        _profile.startsWith('EAL');
    final acexTarget = p?.acexHours ?? 0;
    final accTarget = p?.accHours ?? 0;
    final acex = math.min(
      acexHours,
      acexTarget > 0
          ? acexTarget
          : eal
          ? 390.0
          : 0.0,
    );
    final acc = math.min(
      accHours,
      accTarget > 0
          ? accTarget
          : eal
          ? 120.0
          : 0.0,
    );
    return MatrixProgress(
      doneHours: mandatory + optative + acex + acc,
      totalHours: p?.totalHours ?? 0,
      mandatoryHours: mandatory,
      optativeHours: optative,
      acexHours: acex,
      accHours: acc,
      completedCount: count,
      totalCount: counted.length,
    );
  }

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
          (row['grade'] is! String || _validatedGrade(row['grade']) == null)) {
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
    notifyListeners();
    return true;
  }

  void resetProfileProgress() {
    if (selectedCourse == null || activeProfile == null) return;
    final previous = List<Subject>.of(_subjects);
    _hydrateSubjects(importedSubjects: []);
    _replaceProfileCompletions(previous);
    setHours(acex: 0, acc: 0);
    _persistProgress();
    notifyListeners();
  }

  void _replaceProfileCompletions(List<Subject> previous) {
    _migrateCompletions();
    final identities = [
      ...previous,
      ...countedSubjects,
    ].map(_completionIdentity).toSet();
    final next = completedDisciplines
        .where((entry) => !identities.contains(entry))
        .toSet();
    next.addAll(
      countedSubjects
          .where((s) => s.raw['status'] == 'concluido')
          .map(_completionIdentity),
    );
    _write(_completionKey, jsonEncode(next.toList()..sort()));
    schedule.removeWhere(isCompleted);
    _persistSchedule();
  }

  String exportBackup() => jsonEncode({
    for (final key in _staticBackupKeys) key: _read(key),
    for (final e in _storage.entries)
      if (isBackupStorageKey(e.key)) e.key: e.value,
  });
  Future<bool> importBackup(String value) async {
    final parsed = _json(value);
    if (parsed is! Map || parsed.isEmpty) return false;
    final accepted = <String, String?>{};
    for (final entry in parsed.entries) {
      if (entry.key is! String || !isBackupStorageKey(entry.key)) continue;
      if (entry.value != null && entry.value is! String) return false;
      accepted[entry.key] = entry.value as String?;
    }
    if (accepted.isEmpty) return false;
    // Resolve legacy completions using only the incoming backup, before mixing with current data.
    final staged = AppState(
      repositories: repositories,
      assetLoader: _loadAsset,
    );
    staged._storage.addAll({
      for (final e in accepted.entries)
        if (e.value != null) e.key: e.value!,
    });
    final courseIds = <String>{
      if (staged._read('selectedCourse') != null)
        staged._read('selectedCourse')!,
      ...courses.map((e) => e.id),
    };
    for (final id in courseIds) {
      staged.selectedCourse =
          courses.where((e) => e.id == id).firstOrNull ??
          CourseMeta.fromJson({'id': id});
      if (!accepted.containsKey(staged._completionKey) &&
          accepted.keys.any(
            (k) =>
                k.startsWith('${id}_matriz_progress') ||
                k.startsWith('completedDisciplines_${id}_') ||
                id == 'bcc' && k == 'completedDisciplines',
          )) {
        staged._migrateCompletions();
        accepted[staged._completionKey] = staged._read(staged._completionKey);
      }
    }
    final previous = {for (final key in accepted.keys) key: _read(key)};
    try {
      for (final e in accepted.entries) {
        if (e.value == null) {
          if (_storageReady) await repositories.localStorage.remove(e.key);
          _storage.remove(e.key);
        } else {
          if (_storageReady) {
            await repositories.localStorage.write(e.key, e.value!);
          }
          _storage[e.key] = e.value!;
        }
      }
    } catch (_) {
      for (final e in previous.entries) {
        _write(e.key, e.value);
      }
      return false;
    }
    themeMode = switch (_read('themePreference')) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    selectedSemester = _read('selectedSemester') ?? selectedSemester;
    final course = courses
        .where((e) => e.id == _read('selectedCourse'))
        .firstOrNull;
    await selectCourse(course);
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    repositories.dispose();
    super.dispose();
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
