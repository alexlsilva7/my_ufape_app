import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:result_dart/result_dart.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_repositories.dart';
import '../../core/academic_context.dart';
import '../../core/models.dart';
import '../../core/exceptions/app_exception.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/extraction_repository.dart';
import '../../data/parsers/admin_data.dart';

enum CourseEditDomain { settings, curriculum, schedule }

/// Immutable review bound to the exact draft that was compared.
class AdminImportPreview {
  AdminImportPreview._({
    required this._owner,
    required this._domain,
    required this._revision,
    required this._baseline,
    required this._inputId,
    required Object candidate,
    required List<String> errors,
    required List<String> changes,
    required this.merge,
    this.semester,
    Object? extraction,
  }) : _candidate = CourseEditorViewModel._freeze(candidate),
       _extraction = CourseEditorViewModel._freeze(extraction),
       errors = List.unmodifiable(errors),
       changes = List.unmodifiable(changes);

  final CourseEditorViewModel _owner;
  final CourseEditDomain _domain;
  final int _revision;
  final String _baseline, _inputId;
  final Object _candidate;
  final Object? _extraction;
  final bool merge;
  final String? semester;
  final List<String> errors, changes;
  bool get schedule => _domain == CourseEditDomain.schedule;
  bool get canApply => errors.isEmpty && changes.isNotEmpty;
}

/// Owns the administrative draft. No controllers, dialogs or navigation.
class CourseEditorViewModel extends ChangeNotifier {
  CourseEditorViewModel(this.repository);
  final CourseRepository repository;
  List<Json> _courses = [], _schedule = [];
  Json _course = {}, _curriculum = {};
  Json? _courseView, _curriculumView;
  List<Json>? _scheduleView;
  final Map<CourseEditDomain, String> _baselines = {};
  final Map<CourseEditDomain, String> _serializedDrafts = {};
  String _id = '', _inputId = '', _name = '', _shortName = '', _semester = '';
  bool _creating = false, _loading = false, _saving = false, _disposed = false;
  int _loadVersion = 0;
  AppException? _failure;
  String? _warning;

  String get id => _id;
  String get inputId => _inputId;
  String get name => _name;
  String get shortName => _shortName;
  String get semester => _semester;
  bool get creating => _creating;
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  bool get isBusy => _loading || _saving;
  AppException? get failure => _failure;
  String? get errorMessage => _failure?.message;
  String? get warningMessage => _warning;
  List<Json> get courses =>
      List.unmodifiable(_courses.map((row) => _freeze(row) as Json));
  Json get course => _courseView ??= _freeze(_course) as Json;
  Json get curriculum => _curriculumView ??= _freeze(_curriculum) as Json;
  List<Json> get schedule => _scheduleView ??= List.unmodifiable(
    _schedule.map((row) => _freeze(row) as Json),
  );

  static dynamic _freeze(dynamic value) => switch (value) {
    Map value => Map<String, dynamic>.unmodifiable(
      value.map((key, item) => MapEntry('$key', _freeze(item))),
    ),
    List value => List<dynamic>.unmodifiable(value.map(_freeze)),
    _ => value,
  };
  void _notify({bool documents = false}) {
    if (documents) {
      _courseView = null;
      _curriculumView = null;
      _scheduleView = null;
    }
    if (!_disposed) notifyListeners();
  }

  AppException _error(Object cause, StackTrace stack) =>
      AppException('$cause', cause: cause, stackTrace: stack);
  void updateFields({
    String? inputId,
    String? name,
    String? shortName,
    String? semester,
  }) {
    if (_disposed) return;
    if ((name != null && name != _name) ||
        (shortName != null && shortName != _shortName)) {
      _serializedDrafts.remove(CourseEditDomain.settings);
    }
    if (semester != null && semester != _semester) {
      _serializedDrafts.remove(CourseEditDomain.schedule);
    }
    _inputId = inputId ?? _inputId;
    _name = name ?? _name;
    _shortName = shortName ?? _shortName;
    _semester = semester ?? _semester;
    _notify();
  }

  Json _settings() => {
    'name': _name.trim(),
    'shortName': _shortName.trim(),
    for (final key in visibilityKeys) key: _course[key],
  };
  static const visibilityKeys = [
    'hidden',
    'showSchedule',
    'showDisciplines',
    'showMatriz',
    'visibleSemesters',
  ];
  String _serialized(CourseEditDomain domain) => _serializedDrafts.putIfAbsent(
    domain,
    () => jsonEncode(switch (domain) {
      CourseEditDomain.settings => _settings(),
      CourseEditDomain.curriculum => _curriculum,
      CourseEditDomain.schedule => {
        'semester': _semester,
        'schedule': _schedule,
        'extraction': _course['scheduleExtraction'],
      },
    }),
  );
  bool get hasPendingChanges =>
      _baselines.isNotEmpty && CourseEditDomain.values.any(isDirty);
  bool isDirty(CourseEditDomain domain) =>
      _baselines.containsKey(domain) &&
      _baselines[domain] != _serialized(domain);
  void _baseline() {
    _serializedDrafts.clear();
    for (final domain in CourseEditDomain.values) {
      _baselines[domain] = _serialized(domain);
    }
  }

  void newCourse() {
    if (_disposed || _saving) return;
    ++_loadVersion;
    _loading = false;
    _creating = true;
    _id = '';
    _inputId = '';
    _name = '';
    _shortName = '';
    _semester = '';
    _course = {
      'hidden': false,
      'showSchedule': true,
      'showDisciplines': true,
      'showMatriz': true,
      'visibleSemesters': [],
      'semesters': [],
    };
    _curriculum = normalizeCurriculum({});
    _schedule = [];
    _failure = null;
    _warning = null;
    _baseline();
    _notify(documents: true);
  }

  Future<void> _readDraft(String id, String? semester, int version) async {
    final data = object(
      cloneJson(
        await repository.getDocument(
          id,
          semester: semester,
          strict: semester != null,
        ),
      ),
    );
    final nextCourse = object(data['course']);
    final nextCurriculum = normalizeCurriculum(data['curriculum']);
    final nextSchedule = records(data['schedule']);
    final nextSemester =
        semester ??
        '${data['resolvedSemester'] ?? (nextCourse['visibleSemesters'] as List? ?? []).firstOrNull ?? (nextCourse['semesters'] as List? ?? []).lastOrNull ?? ''}';
    nextCourse['visibleSemesters'] ??= cloneJson(nextCourse['semesters'] ?? []);
    nextCourse['scheduleExtraction'] = cloneJson(data['scheduleExtraction']);
    if (_disposed || version != _loadVersion) return;
    _creating = false;
    _id = id;
    _inputId = id;
    _course = nextCourse;
    _curriculum = nextCurriculum;
    _schedule = nextSchedule;
    _name = '${nextCourse['name'] ?? ''}';
    _shortName = '${nextCourse['shortName'] ?? ''}';
    _semester = nextSemester;
    _baseline();
    _notify(documents: true);
  }

  AsyncResult<Unit> _load(Future<void> Function(int) action) async {
    if (_disposed || _saving) {
      return Failure(
        _error(StateError('Editor indisponível.'), StackTrace.current),
      );
    }
    final version = ++_loadVersion;
    _loading = true;
    _failure = null;
    _warning = null;
    _notify();
    try {
      await action(version);
      return Success(unit);
    } catch (cause, stack) {
      final failure = _error(cause, stack);
      if (!_disposed && version == _loadVersion) _failure = failure;
      return Failure(failure);
    } finally {
      if (!_disposed && version == _loadVersion) {
        _loading = false;
        _notify();
      }
    }
  }

  AsyncResult<Unit> loadCourse(String id, {String? semester}) =>
      _load((version) => _readDraft(id, semester, version));
  AsyncResult<Unit> reloadCourses({String? preferredId}) =>
      _load((version) async {
        final rows = records((await repository.list())['courses']);
        if (_disposed || version != _loadVersion) return;
        _courses = rows;
        if (rows.isEmpty) {
          newCourse();
          return;
        }
        final preferred = _id.isNotEmpty ? _id : preferredId;
        await _readDraft(
          rows.any((row) => row['id'] == preferred)
              ? preferred!
              : '${rows.first['id']}',
          null,
          version,
        );
      });

  void setVisibility(String key, dynamic value) {
    if (!visibilityKeys.contains(key)) throw ArgumentError.value(key);
    _serializedDrafts.remove(CourseEditDomain.settings);
    _course = {..._course, key: cloneJson(value)};
    _notify(documents: true);
  }

  void setSemesterVisible(String semester, bool visible) {
    final list = List<dynamic>.from(_course['visibleSemesters'] ?? []);
    if (visible && !list.contains(semester)) list.add(semester);
    if (!visible) list.remove(semester);
    setVisibility('visibleSemesters', list);
  }

  void preferSemester(String semester) => setVisibility('visibleSemesters', [
    semester,
    ...(_course['visibleSemesters'] as List? ?? []).where(
      (item) => item != semester,
    ),
  ]);
  void setCurriculumField(String key, dynamic value) {
    _serializedDrafts.remove(CourseEditDomain.curriculum);
    _curriculum = {..._curriculum, key: cloneJson(value)};
    _notify(documents: true);
  }

  void replaceCurriculum(dynamic value) {
    final next = normalizeCurriculum(value);
    _serializedDrafts.remove(CourseEditDomain.curriculum);
    _curriculum = next;
    _notify(documents: true);
  }

  void applySchedule(List<Json> rows, {String? semester, Object? extraction}) {
    _serializedDrafts.remove(CourseEditDomain.schedule);
    _schedule = records(cloneJson(rows));
    _semester = semester ?? _semester;
    _course = {..._course, 'scheduleExtraction': cloneJson(extraction)};
    _notify(documents: true);
  }

  String? recordDeletionError(bool schedule, int index) {
    if (schedule) return null;
    final row = records(_curriculum['subjects'])[index];
    final dependents = records(_curriculum['treeSubjects'])
        .where((node) => (node['prereqs'] as List? ?? []).contains(row['id']));
    return dependents.isEmpty
        ? null
        : 'Remova primeiro os pré-requisitos em: ${dependents.map((node) => node['name']).join(', ')}.';
  }

  void deleteRecord(bool schedule, int index) {
    final error = recordDeletionError(schedule, index);
    if (error != null) throw FormatException(error);
    final rows = records(
      cloneJson(schedule ? _schedule : _curriculum['subjects']),
    );
    final row = rows.removeAt(index);
    if (schedule) {
      _serializedDrafts.remove(CourseEditDomain.schedule);
      _schedule = rows;
      _notify(documents: true);
    } else {
      replaceCurriculum({
        ..._curriculum,
        'subjects': rows,
        'treeSubjects': records(_curriculum['treeSubjects'])
            .where((node) => node['id'] != row['id'])
            .toList(),
      });
    }
  }

  void editRecord(bool schedule, Json result, {int? index}) {
    final rows = records(
      cloneJson(schedule ? _schedule : _curriculum['subjects']),
    );
    if (index != null && result['id'] != rows[index]['id']) {
      throw const FormatException(
        'Preserve o identificador do registro existente para manter os vínculos.',
      );
    }
    final next = object(cloneJson(result));
    if (index == null) {
      rows.add(next);
    } else {
      rows[index] = next;
    }
    if (schedule) {
      _serializedDrafts.remove(CourseEditDomain.schedule);
      _schedule = rows;
      _notify(documents: true);
      return;
    }
    final refs = records(next['prerequisites'])
        .map(
          (ref) =>
              ref['id'] ??
              rows
                  .where(
                    (row) =>
                        row['code'] == ref['code'] &&
                        row['profile'] == next['profile'],
                  )
                  .firstOrNull?['id'],
        )
        .whereType<String>()
        .toList();
    replaceCurriculum({
      ..._curriculum,
      'subjects': rows,
      'treeSubjects': records(_curriculum['treeSubjects'])
          .map(
            (node) =>
                node['id'] == next['id'] ? {...node, 'prereqs': refs} : node,
          )
          .toList(),
    });
  }

  void editProfile(Json result, {String? originalId}) {
    if ('${result['id'] ?? ''}'.isEmpty) {
      throw const FormatException('Informe o identificador do perfil.');
    }
    final profiles = records(_curriculum['profiles']);
    if (profiles.any(
      (row) => row['id'] == result['id'] && row['id'] != originalId,
    )) {
      throw const FormatException('Identificador de perfil repetido.');
    }
    if (originalId != null && result['id'] != originalId) {
      throw const FormatException(
        'Preserve o identificador do perfil existente.',
      );
    }
    final index = profiles.indexWhere((row) => row['id'] == originalId);
    if (index < 0) {
      profiles.add(object(cloneJson(result)));
    } else {
      profiles[index] = object(cloneJson(result));
    }
    replaceCurriculum({
      ..._curriculum,
      'profiles': profiles,
      'activeProfileId': _curriculum['activeProfileId'] ?? result['id'],
    });
  }

  String? profileDeletionError(String id) {
    final nodes = records(_curriculum['treeSubjects']);
    final removed = nodes
        .where((node) => node['profile'] == id)
        .map((node) => node['id'])
        .toSet();
    return nodes.any(
          (node) =>
              !removed.contains(node['id']) &&
              (node['prereqs'] as List? ?? []).any(removed.contains),
        )
        ? 'Este perfil possui vínculos de pré-requisito externos. Remova esses vínculos antes.'
        : null;
  }

  void deleteProfile(String id) {
    final error = profileDeletionError(id);
    if (error != null) throw FormatException(error);
    final profiles = records(_curriculum['profiles'])
        .where((row) => row['id'] != id)
        .toList();
    replaceCurriculum({
      ..._curriculum,
      'profiles': profiles,
      for (final key in ['subjects', 'treeSubjects'])
        key: records(_curriculum[key])
            .where((row) => row['profile'] != id)
            .toList(),
      if (_curriculum['activeProfileId'] == id)
        'activeProfileId': profiles.firstOrNull?['id'],
    });
  }

  void editLinks(String id, Json result) {
    final ids = records(_curriculum['treeSubjects'])
        .map((row) => row['id'])
        .toSet();
    if ((result['prereqs'] as List? ?? []).any(
      (target) => !ids.contains(target) || target == id,
    )) {
      throw const FormatException(
        'Pré-requisito inexistente ou autorreferente.',
      );
    }
    replaceCurriculum({
      ..._curriculum,
      'treeSubjects': records(_curriculum['treeSubjects'])
          .map((row) => row['id'] == id ? {...row, ...result, 'id': id} : row)
          .toList(),
      'subjects': records(_curriculum['subjects'])
          .map(
            (row) => row['id'] == id
                ? {
                    ...row,
                    'corequisites': result['corequisites'],
                    'equivalences': result['equivalences'],
                    'prerequisites': (result['prereqs'] as List? ?? []).map((
                      targetId,
                    ) {
                      final target = records(_curriculum['subjects'])
                          .where((row) => row['id'] == targetId)
                          .firstOrNull;
                      return {
                        'id': targetId,
                        'code': target?['code'],
                        'name': target?['name'],
                      };
                    }).toList(),
                  }
                : row,
          )
          .toList(),
    });
  }

  AsyncResult<Unit> save(CourseEditDomain domain) async {
    if (_disposed || isBusy) {
      return Failure(
        _error(
          StateError('Aguarde a operação em andamento.'),
          StackTrace.current,
        ),
      );
    }
    _saving = true;
    _failure = null;
    _warning = null;
    _notify();
    try {
      final id = _creating ? _inputId.trim() : _id;
      final name = _name.trim(), shortName = _shortName.trim();
      if (name.isEmpty || shortName.isEmpty) {
        throw const FormatException('Informe nome e sigla do curso.');
      }
      if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(id)) {
        throw const FormatException(
          'Identificador: letras minúsculas, números, hífen ou sublinhado.',
        );
      }
      if (_creating && domain != CourseEditDomain.settings) {
        throw const FormatException('Salve o novo curso primeiro.');
      }
      final settings = object(cloneJson(_settings()));
      final semester = _semester;
      final schedule = records(cloneJson(_schedule));
      final extraction = cloneJson(_course['scheduleExtraction']);
      final previousCurriculum = domain == CourseEditDomain.curriculum
          ? _serialized(CourseEditDomain.curriculum)
          : null;
      final curriculum = domain == CourseEditDomain.curriculum
          ? normalizeCurriculum(_curriculum)
          : _curriculum;
      final baseline = jsonEncode(switch (domain) {
        CourseEditDomain.settings => settings,
        CourseEditDomain.curriculum => curriculum,
        CourseEditDomain.schedule => {
          'semester': semester,
          'schedule': schedule,
          'extraction': extraction,
        },
      });
      if (domain == CourseEditDomain.settings) {
        if (_creating) {
          if (_courses.any((row) => row['id'] == id)) {
            throw const FormatException(
              'Já existe um curso com este identificador.',
            );
          }
          await repository.save({
            'id': id,
            'name': name,
            'shortName': shortName,
          });
          if (_disposed) return Success(unit);
          // Creation is already durable even if visibility subsequently fails.
          _id = id;
          _inputId = id;
          _creating = false;
          _course = {
            ..._course,
            'id': id,
            'name': name,
            'shortName': shortName,
          };
          if (!_courses.any((row) => row['id'] == id)) {
            _courses = [..._courses, object(cloneJson(_course))];
          }
        } else {
          await repository.updateMetadata(id, {
            'name': name,
            'shortName': shortName,
          });
        }
        await repository.updateVisibility(id, {
          for (final key in visibilityKeys) key: settings[key],
        });
      } else {
        if (domain == CourseEditDomain.schedule &&
            !RegExp(r'^\d{4}\.[12]$').hasMatch(semester)) {
          throw const FormatException('Use um semestre AAAA.1 ou AAAA.2.');
        }
        final errors = validateAdminData(
          domain == CourseEditDomain.schedule ? schedule : curriculum,
          schedule: domain == CourseEditDomain.schedule,
        );
        if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
        await repository.save({
          'id': id,
          'name': name,
          'shortName': shortName,
          if (domain == CourseEditDomain.curriculum)
            'curriculum': {
              ...curriculum,
              'courseName': name,
              'courseShortName': shortName,
            },
          if (domain == CourseEditDomain.schedule) ...{
            'semester': semester,
            'schedule': schedule
                .map((row) => {...row, 'semester': semester})
                .toList(),
            'scheduleExtraction': extraction,
          },
        });
      }
      if (_disposed) return Success(unit);
      // Only the submitted version becomes clean; edits made while awaiting stay dirty.
      if (domain == CourseEditDomain.curriculum &&
          _serialized(CourseEditDomain.curriculum) == previousCurriculum) {
        _serializedDrafts.remove(CourseEditDomain.curriculum);
        _curriculum = object(cloneJson(curriculum));
      }
      _baselines[domain] = baseline;
      _notify(documents: true);
      try {
        final rows = records((await repository.list())['courses']);
        if (!_disposed) _courses = rows;
      } catch (cause) {
        if (!_disposed) {
          _warning =
              'Dados salvos, mas a lista de cursos não pôde ser atualizada: $cause';
        }
      }
      return Success(unit);
    } catch (cause, stack) {
      final failure = _error(cause, stack);
      if (!_disposed) _failure = failure;
      return Failure(failure);
    } finally {
      _saving = false;
      _notify();
    }
  }

  AsyncResult<Unit> deleteCourse() async {
    if (_disposed || isBusy || _id.isEmpty) {
      return Failure(
        _error(StateError('Editor indisponível.'), StackTrace.current),
      );
    }
    _saving = true;
    _failure = null;
    _notify();
    try {
      await repository.delete(_id);
      if (!_disposed) {
        _id = '';
        _baselines.clear();
        _notify();
      }
      return Success(unit);
    } catch (cause, stack) {
      final failure = _error(cause, stack);
      if (!_disposed) _failure = failure;
      return Failure(failure);
    } finally {
      _saving = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_loadVersion;
    super.dispose();
  }
}

/// Coordinates the administrative session, draft and extraction lifecycle.
class AdminViewModel extends ChangeNotifier {
  AdminViewModel({
    required this._appRepositories,
    required AcademicContext academicContext,
    required AdminRepositories adminRepositories,
    required this._editor,
    required this._disposeScope,
    this._pollingInterval = const Duration(seconds: 3),
    String Function()? tokenFactory,
  }) : _context = academicContext,
       _repositories = adminRepositories,
       _tokenFactory = tokenFactory ?? const Uuid().v4 {
    _editor.addListener(_notify);
  }

  final AppRepositories _appRepositories;
  final AcademicContext _context;
  final AdminRepositories _repositories;
  final CourseEditorViewModel _editor;
  final void Function() _disposeScope;
  final Duration _pollingInterval;
  final String Function() _tokenFactory;
  bool _disposed = false;
  bool _initializing = true, _authorized = false, _running = false;
  bool _extracting = false;
  Json? _configuration, _snapshot, _extracted;
  Json _pipeline = {'concurrency': 1, 'models': <String, dynamic>{}};
  String _message = '', _monitorError = '', _resumeToken = '';
  ExtractionMode _mode = ExtractionMode.tree;
  String _resultMode = 'tree';
  AppException? _failure;
  Future<void>? _initialization;
  Timer? _monitor;
  int _extractionVersion = 0;
  int? _pollingVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool get initializing => _initializing;
  bool get authorized => _authorized;
  bool get isBusy => _running || _editor.isBusy || _migrationBusy;
  bool get extracting => _extracting;
  bool get isLocal => _appRepositories.isLocal;
  bool get sessionConfigured => _repositories.auth.configured;
  bool get hasConfiguration => _configuration != null;
  bool get authConfigured => _configuration?['authConfigured'] == true;
  bool get supportsMigration => _configuration?['supportsMigration'] != false;
  bool get supportsExtraction => _configuration?['supportsExtraction'] != false;
  String get dataSourceLabel =>
      '${_configuration?['dataSource'] ?? 'servidor'}';
  String get message => _message;
  String get monitorError => _monitorError;
  String get resumeToken => _resumeToken;
  String get extractionMode => _mode.name;
  String get resultMode => _resultMode;
  AppException? get failure => _failure;
  Json get pipeline => CourseEditorViewModel._freeze(_pipeline) as Json;
  Json? get snapshot => _snapshot == null
      ? null
      : CourseEditorViewModel._freeze(_snapshot) as Json;
  Json? get extracted => _extracted == null
      ? null
      : CourseEditorViewModel._freeze(_extracted) as Json;

  CourseMeta? get selectedCourse => _context.selectedCourse;
  String get id => _editor.id;
  String get inputId => _editor.inputId;
  String get name => _editor.name;
  String get shortName => _editor.shortName;
  String get semester => _editor.semester;
  bool get creating => _editor.creating;
  bool get hasPendingChanges => _editor.hasPendingChanges;
  List<Json> get courses => _editor.courses;
  List<Json> get schedule => _editor.schedule;
  Json get course => _editor.course;
  Json get curriculum => _editor.curriculum;

  void showMessage(String value) {
    if (_disposed) return;
    _message = value;
    _notify();
  }

  void _recordFailure(Object cause, StackTrace stack) {
    if (_disposed) return;
    _failure = AppException('$cause', cause: cause, stackTrace: stack);
    _message = _failure!.message;
  }

  Future<void> initialize() {
    if (_disposed) return Future.value();
    if (_initialization != null) return _initialization!;
    return _initialization = _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    _initializing = true;
    _failure = null;
    _notify();
    try {
      final configuration = await _repositories.admin.configuration();
      if (_disposed) return;
      _configuration = object(cloneJson(configuration));
      if (_configuration!['authRequired'] == false) {
        _authorized = true;
        (await reloadCourses()).getOrThrow();
      }
    } catch (cause, stack) {
      _recordFailure(cause, stack);
    } finally {
      _initializing = false;
      _notify();
    }
  }

  Future<bool> run(Future<void> Function() action, {String? success}) async {
    if (_disposed || isBusy) return false;
    _running = true;
    _message = '';
    _failure = null;
    _notify();
    try {
      await action();
      if (_disposed) return false;
      if (success != null) _message = success;
      return true;
    } catch (cause, stack) {
      _recordFailure(cause, stack);
      return false;
    } finally {
      _running = false;
      _notify();
    }
  }

  Future<bool> login(String email, String password) => run(() async {
    await _repositories.auth.signIn(email, password);
    if (_disposed) return;
    try {
      await _repositories.admin.validateSession();
      if (_disposed) return;
      (await reloadCourses()).getOrThrow();
      if (!_disposed) _authorized = true;
    } catch (cause, stack) {
      if (!_disposed) {
        _authorized = false;
        try {
          await _repositories.auth.signOut();
        } catch (_) {
          // Discard credentials even if the remote logout fails.
          if (!_disposed) _repositories.auth.clear();
        }
      }
      Error.throwWithStackTrace(cause, stack);
    }
  });

  Future<void> signOut() async {
    await _repositories.auth.signOut();
    if (_disposed) return;
    _authorized = false;
    _notify();
  }

  Future<void> saveCourse(CourseEditDomain domain) async {
    await run(() async {
      (await _editor.save(domain)).getOrThrow();
      if (_disposed) return;
      if (isLocal) await _context.refresh();
      if (_disposed) return;
      _message =
          _editor.warningMessage ??
          (isLocal
              ? 'Alterações salvas neste dispositivo.'
              : 'Alterações salvas no servidor.');
    });
  }

  void setExtractionMode(String value) {
    if (_disposed || _extracting) return;
    _mode = ExtractionMode.fromName(value);
    _notify();
  }

  void setPipeline(Json value) {
    if (_disposed || _extracting) return;
    final concurrency = value['concurrency'];
    if (concurrency is! int ||
        concurrency < 1 ||
        concurrency > 6 ||
        value['models'] is! Map) {
      throw const FormatException(
        'Use concurrency entre 1 e 6 e models como objeto por etapa.',
      );
    }
    _pipeline = object(cloneJson(value));
    _notify();
  }

  bool _isCurrent(int version) => !_disposed && version == _extractionVersion;

  Future<void> startExtraction({
    required List<Json> files,
    required String textContent,
    required String model,
  }) async {
    if (_disposed || isBusy || _extracting) return;
    if (files.isEmpty && textContent.trim().isEmpty) {
      showMessage('Envie documentos ou cole o texto.');
      return;
    }
    final version = _beginExtraction(_tokenFactory());
    final token = _resumeToken;
    final mode = _mode;
    final input = {
      'token': token,
      'mode': mode.name,
      'input': {
        'files': cloneJson(files),
        'textContent': textContent,
        if (model.trim().isNotEmpty) 'model': model.trim(),
        'pipeline': cloneJson(_pipeline),
      },
    };
    try {
      final snapshot = await _repositories.extraction.start(input);
      if (!_isCurrent(version)) return;
      _snapshot = object(cloneJson(snapshot));
      _notify();
      if (_snapshot?['token'] == token) {
        await _performResume(token, model, version);
      }
    } catch (cause, stack) {
      _recordFailure(cause, stack);
    } finally {
      _finishExtraction(version);
    }
  }

  Future<void> resumeExtraction({
    required String token,
    required String model,
  }) async {
    if (_disposed || isBusy || _extracting) return;
    if (token.trim().isEmpty) {
      showMessage('Informe o token de retomada.');
      return;
    }
    final version = _beginExtraction(token.trim());
    try {
      await _performResume(_resumeToken, model, version);
    } catch (cause, stack) {
      _recordFailure(cause, stack);
      if (!_disposed) {
        _message =
            'Extração interrompida: $cause. Retome usando o token preservado.';
      }
    } finally {
      _finishExtraction(version);
    }
  }

  int _beginExtraction(String token) {
    _monitor?.cancel();
    _resumeToken = token;
    _snapshot = null;
    _extracted = null;
    _extracting = true;
    _message = '';
    _monitorError = '';
    _failure = null;
    final version = ++_extractionVersion;
    _notify();
    return version;
  }

  Future<void> _performResume(String token, String model, int version) async {
    await _poll(token, version);
    if (!_isCurrent(version)) return;
    final serverMode = _snapshot?['mode'];
    if (ExtractionMode.values.any((mode) => mode.name == serverMode)) {
      _mode = ExtractionMode.fromName('$serverMode');
    }
    final mode = _mode;
    final request = {
      'resumeToken': token,
      if (model.trim().isNotEmpty) 'model': model.trim(),
      'pipeline': cloneJson(_pipeline),
    };
    _monitor = Timer.periodic(_pollingInterval, (_) {
      unawaited(_poll(token, version));
    });
    final result = await _repositories.extraction.resume(mode, request);
    if (!_isCurrent(version)) return;
    _extracted = object(cloneJson(result));
    _resultMode = mode.name;
    _message =
        'Extração concluída. Revise o resultado antes de aplicar ao rascunho.';
    _notify();
    await _poll(token, version);
  }

  Future<void> refreshExtraction() => _poll(_resumeToken, _extractionVersion);

  Future<void> _poll(String token, int version) async {
    if (!_isCurrent(version) || token.isEmpty || _pollingVersion == version) {
      return;
    }
    _pollingVersion = version;
    try {
      final result = await _repositories.extraction.get(token);
      if (!_isCurrent(version)) return;
      _snapshot = object(cloneJson(result));
      _monitorError = '';
      _notify();
    } catch (cause) {
      if (!_isCurrent(version)) return;
      _monitorError =
          'Acompanhamento indisponível: $cause. A última etapa foi preservada.';
      _notify();
    } finally {
      if (_pollingVersion == version) _pollingVersion = null;
    }
  }

  void _finishExtraction(int version) {
    if (!_isCurrent(version)) return;
    _monitor?.cancel();
    _monitor = null;
    _extracting = false;
    _notify();
  }

  AdminImportPreview prepareImport(
    dynamic incoming, {
    required bool schedule,
    bool merge = false,
  }) {
    if (_disposed || isBusy) throw StateError('Editor indisponível.');
    final input = cloneJson(incoming);
    final raw = schedule
        ? (input is List
              ? input
              : object(input)['disciplines'] ?? object(input)['schedule'])
        : input;
    if (schedule && raw is! List) {
      throw const FormatException(
        'O JSON deve conter uma lista de turmas ou disciplines/schedule.',
      );
    }
    if (!schedule &&
        raw is! List &&
        (raw is! Map ||
            !['subjects', 'treeSubjects', 'profiles'].any(raw.containsKey))) {
      throw const FormatException(
        'O currículo deve conter subjects, treeSubjects ou profiles.',
      );
    }
    dynamic candidate = schedule ? records(raw) : normalizeCurriculum(raw);
    if (merge) {
      List<Json> combine(List<Json> old, List<Json> next) {
        final out = records(cloneJson(old));
        for (final row in next) {
          final index = out.indexWhere(
            (item) => row['id'] != null
                ? item['id'] == row['id']
                : item['code'] == row['code'] &&
                      item['profile'] == row['profile'],
          );
          if (index < 0) {
            out.add(row);
          } else {
            out[index] = {...out[index], ...row};
          }
        }
        return out;
      }

      candidate = schedule
          ? combine(this.schedule, records(candidate))
          : normalizeCurriculum({
              ...curriculum,
              ...object(candidate),
              for (final key in ['subjects', 'treeSubjects', 'profiles'])
                key: combine(
                  records(curriculum[key]),
                  records(object(candidate)[key]),
                ),
            });
    }
    final domain = schedule
        ? CourseEditDomain.schedule
        : CourseEditDomain.curriculum;
    final baseline = _editor._serialized(domain);
    final importedSemester =
        input is Map &&
            RegExp(r'^\d{4}\.[12]$').hasMatch('${input['semester']}')
        ? '${input['semester']}'
        : null;
    final extraction = input is Map ? input['_extraction'] : null;
    return AdminImportPreview._(
      owner: _editor,
      domain: domain,
      revision: _editor._loadVersion,
      baseline: baseline,
      inputId: inputId,
      candidate: candidate,
      errors: validateAdminData(candidate, schedule: schedule),
      changes: changesBetween(
        jsonDecode(baseline),
        schedule
            ? {
                'semester': importedSemester ?? semester,
                'schedule': candidate,
                'extraction': extraction,
              }
            : candidate,
      ),
      merge: merge,
      semester: importedSemester,
      extraction: extraction,
    );
  }

  bool applyImport(AdminImportPreview preview) {
    if (_disposed || isBusy || !preview.canApply) return false;
    if (!identical(preview._owner, _editor) ||
        preview._revision != _editor._loadVersion ||
        preview._inputId != inputId ||
        preview._baseline != _editor._serialized(preview._domain)) {
      showMessage(
        'O rascunho mudou. Revise a importação novamente antes de aplicar.',
      );
      return false;
    }
    if (preview.schedule) {
      _editor.applySchedule(
        records(preview._candidate),
        semester: preview.semester,
        extraction: preview._extraction,
      );
    } else {
      _editor.replaceCurriculum(preview._candidate);
    }
    showMessage(
      'Importação aplicada ao rascunho. Revise e salve quando estiver pronto.',
    );
    return true;
  }

  void updateFields({
    String? inputId,
    String? name,
    String? shortName,
    String? semester,
  }) => _editor.updateFields(
    inputId: inputId,
    name: name,
    shortName: shortName,
    semester: semester,
  );
  AsyncResult<Unit> reloadCourses({String? preferredId}) =>
      _editor.reloadCourses(preferredId: preferredId ?? selectedCourse?.id);
  AsyncResult<Unit> loadCourse(String id, {String? semester}) =>
      _editor.loadCourse(id, semester: semester);
  AsyncResult<Unit> deleteCourse() => _editor.deleteCourse();
  void newCourse() => _editor.newCourse();
  void setVisibility(String key, dynamic value) =>
      _editor.setVisibility(key, value);
  void setSemesterVisible(String semester, bool visible) =>
      _editor.setSemesterVisible(semester, visible);
  void preferSemester(String semester) => _editor.preferSemester(semester);
  void setCurriculumField(String key, dynamic value) =>
      _editor.setCurriculumField(key, value);
  void replaceCurriculum(dynamic value) => _editor.replaceCurriculum(value);
  void applySchedule(List<Json> rows, {String? semester, Object? extraction}) =>
      _editor.applySchedule(rows, semester: semester, extraction: extraction);
  String? recordDeletionError(bool schedule, int index) =>
      _editor.recordDeletionError(schedule, index);
  void deleteRecord(bool schedule, int index) =>
      _editor.deleteRecord(schedule, index);
  void editRecord(bool schedule, Json result, {int? index}) =>
      _editor.editRecord(schedule, result, index: index);
  void editProfile(Json result, {String? originalId}) =>
      _editor.editProfile(result, originalId: originalId);
  String? profileDeletionError(String id) => _editor.profileDeletionError(id);
  void deleteProfile(String id) => _editor.deleteProfile(id);
  void editLinks(String id, Json result) => _editor.editLinks(id, result);

  List<Json> _feedbackItems = [];
  int _feedbackTotal = 0;
  bool _feedbackBusy = false;
  AppException? _feedbackFailure;
  String _feedbackMessage = '';
  String _feedbackCategory = '', _feedbackStatus = '', _feedbackCourse = '';
  int _feedbackOffset = 0;
  List<Json> get feedbackItems => _feedbackItems;
  int get feedbackTotal => _feedbackTotal;
  bool get feedbackBusy => _feedbackBusy;
  String get feedbackMessage => _feedbackMessage;
  AppException? get feedbackFailure => _feedbackFailure;

  Future<void> _readFeedback() async {
    final data = await _repositories.feedback.list(
      category: _feedbackCategory,
      status: _feedbackStatus,
      course: _feedbackCourse,
      offset: _feedbackOffset,
    );
    if (_disposed) return;
    _feedbackItems = List.unmodifiable(
      records(data['items'])
          .map((row) => CourseEditorViewModel._freeze(row) as Json),
    );
    _feedbackTotal = (data['total'] as num?)?.toInt() ?? 0;
  }

  Future<bool> loadFeedback({
    String category = '',
    String status = '',
    String course = '',
    int offset = 0,
  }) async {
    if (_disposed || _feedbackBusy) return false;
    _feedbackCategory = category;
    _feedbackStatus = status;
    _feedbackCourse = course;
    _feedbackOffset = offset;
    _feedbackBusy = true;
    _feedbackFailure = null;
    _feedbackMessage = '';
    _notify();
    try {
      await _readFeedback();
      return !_disposed;
    } catch (cause, stack) {
      if (!_disposed) {
        _feedbackFailure = AppException(
          '$cause',
          cause: cause,
          stackTrace: stack,
        );
        _feedbackMessage = '$cause';
      }
      return false;
    } finally {
      _feedbackBusy = false;
      _notify();
    }
  }

  Future<Json?> saveFeedback(
    String id, {
    required String status,
    required String notes,
  }) async {
    if (_disposed || _feedbackBusy) return null;
    _feedbackBusy = true;
    _feedbackFailure = null;
    _feedbackMessage = '';
    _notify();
    try {
      final response = await _repositories.feedback.update(
        id,
        status: status,
        notes: notes,
      );
      if (_disposed) return null;
      if (response['item'] is! Map || object(response['item'])['id'] != id) {
        throw const FormatException(
          'O servidor não confirmou o feedback salvo.',
        );
      }
      final saved = CourseEditorViewModel._freeze(response['item']) as Json;
      _feedbackItems = List.unmodifiable(
        _feedbackItems.map((row) => row['id'] == id ? saved : row),
      );
      try {
        await _readFeedback();
      } catch (cause, stack) {
        if (!_disposed) {
          _feedbackFailure = AppException(
            '$cause',
            cause: cause,
            stackTrace: stack,
          );
          _feedbackMessage = 'Feedback salvo, mas a lista não pôde ser atualizada. Tente atualizar novamente.';
        }
      }
      return _disposed ? null : saved;
    } catch (cause, stack) {
      if (!_disposed) {
        _feedbackFailure = AppException(
          '$cause',
          cause: cause,
          stackTrace: stack,
        );
        _feedbackMessage = '$cause';
      }
      return null;
    } finally {
      _feedbackBusy = false;
      _notify();
    }
  }

  Json? _migrationInventory, _migrationPreview, _migrationRun;
  List<Json> _migrationRuns = [];
  final _migrationSelected = <String>{}, _migrationOverwrite = <String>{};
  bool _migrationBusy = false;
  int _migrationDone = 0, _migrationTotal = 0;
  String _migrationMessage = '';
  AppException? _migrationFailure;
  Json? get migrationInventory => _migrationInventory;
  Json? get migrationPreview => _migrationPreview;
  Json? get migrationRun => _migrationRun;
  List<Json> get migrationRuns => _migrationRuns;
  Set<String> get migrationSelected => Set.unmodifiable(_migrationSelected);
  Set<String> get migrationOverwrite => Set.unmodifiable(_migrationOverwrite);
  bool get migrationBusy => _migrationBusy;
  int get migrationDone => _migrationDone;
  int get migrationTotal => _migrationTotal;
  String get migrationMessage => _migrationMessage;
  AppException? get migrationFailure => _migrationFailure;
  Json _migrationSnapshot(Json value) =>
      CourseEditorViewModel._freeze(cloneJson(value)) as Json;

  void selectMigrationItem(
    String key,
    bool selected, {
    bool overwrite = false,
  }) {
    if (_disposed || isBusy) return;
    if (!records(_migrationInventory?['items'])
        .any((item) => item['key'] == key)) {
      return;
    }
    if (overwrite) {
      if (!_migrationSelected.contains(key)) return;
      selected ? _migrationOverwrite.add(key) : _migrationOverwrite.remove(key);
    } else if (selected) {
      _migrationSelected.add(key);
    } else {
      _migrationSelected.remove(key);
      _migrationOverwrite.remove(key);
    }
    _migrationPreview = null;
    _notify();
  }

  Future<void> _migrationAction(Future<void> Function() action) async {
    if (_disposed || isBusy) return;
    _migrationBusy = true;
    _migrationMessage = '';
    _migrationFailure = null;
    _notify();
    try {
      await action();
    } catch (cause, stack) {
      if (!_disposed) {
        _migrationFailure = AppException(
          '$cause',
          cause: cause,
          stackTrace: stack,
        );
        _migrationMessage = '$cause';
      }
    } finally {
      _migrationBusy = false;
      _notify();
    }
  }

  Future<void> analyzeMigration() => _migrationAction(() async {
    _migrationPreview = null;
    final result = await _repositories.migrations.inventory();
    if (_disposed) return;
    _migrationInventory = _migrationSnapshot(result);
    _migrationOverwrite.clear();
    final keys = records(result['items']).map((row) => '${row['key']}').toSet();
    _migrationSelected.removeWhere((key) => !keys.contains(key));
  });

  Future<void> validateMigration() => _migrationAction(() async {
    _migrationPreview = null;
    if (_migrationSelected.isEmpty ||
        _migrationInventory?['destinationConfigured'] != true) {
      return;
    }
    final result = await _repositories.migrations.validate({
      'selectedKeys': _migrationSelected.toList(),
      'overwriteKeys': _migrationOverwrite.toList(),
    });
    if (_disposed) return;
    _migrationPreview = _migrationSnapshot(result);
    _migrationSelected
      ..clear()
      ..addAll(records(result['items']).map((row) => '${row['key']}'));
    _migrationOverwrite.removeWhere((key) => !_migrationSelected.contains(key));
  });

  Future<void> loadMigrationHistory() =>
      _migrationAction(_readMigrationHistory);
  Future<void> _readMigrationHistory() async {
    final result = await _repositories.migrations.list();
    if (!_disposed) {
      _migrationRuns = List.unmodifiable(
        records(result['runs']).map(_migrationSnapshot),
      );
    }
  }

  Future<void> executeMigration(
    Json approvedPreview,
  ) => _migrationAction(() async {
    if (!identical(approvedPreview, _migrationPreview) ||
        approvedPreview['ready'] != true) {
      _migrationMessage =
          'A seleção mudou. Valide e confirme a migração novamente.';
      return;
    }
    final courses = List<String>.from(
      (approvedPreview['selectedCourseIds'] as List? ?? []).map((id) => '$id'),
    );
    final request = {
      'selectedKeys': _migrationSelected.toList(),
      'overwriteKeys': _migrationOverwrite.toList(),
      'fingerprint': approvedPreview['fingerprint'],
    };
    _migrationPreview = null;
    _migrationDone = 0;
    _migrationTotal = courses.length;
    final started = await _repositories.migrations.start(request);
    if (_disposed) return;
    _migrationRun = _migrationSnapshot(started);
    final id = '${started['id'] ?? ''}';
    if (id.isEmpty) throw const FormatException('Execução sem identificador.');
    _notify();
    final failures = <String>[];
    for (final course in courses) {
      if (_disposed) return;
      try {
        await _repositories.migrations.importCourse(id, course);
      } catch (cause, stack) {
        if (_disposed) return;
        failures.add('$course: $cause');
        _migrationFailure = AppException(
          '$cause',
          cause: cause,
          stackTrace: stack,
        );
      }
      if (_disposed) return;
      _migrationDone++;
      _notify();
    }
    final latest = await _repositories.migrations.get(id);
    if (_disposed) return;
    _migrationRun = _migrationSnapshot(object(latest['run']));
    _migrationMessage = failures.isEmpty
        ? 'Migração processada. Confira o status e o relatório antes de ativar o Supabase como fonte.'
        : 'Execução registrada com falhas: ${failures.join(' · ')}';
    try {
      await _readMigrationHistory();
    } catch (cause, stack) {
      if (!_disposed) {
        _migrationFailure = AppException(
          '$cause',
          cause: cause,
          stackTrace: stack,
        );
        _migrationMessage += ' Não foi possível atualizar o histórico: $cause';
      }
    }
  });

  Future<Json?> loadMigrationReport(String id) async {
    Json? report;
    await _migrationAction(() async {
      final result = await _repositories.migrations.report(id);
      if (!_disposed) report = _migrationSnapshot(result);
    });
    return report;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_extractionVersion;
    _monitor?.cancel();
    _editor.removeListener(_notify);
    _disposeScope();
    super.dispose();
  }
}
