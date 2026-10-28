import 'package:result_dart/result_dart.dart';

import '../../../domain/entities/course_details.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../parsers/academic_course_parser.dart';

import 'dart:convert';

import '../../../core/models.dart';
import '../../../core/data_source.dart';
import '../../../domain/repositories/course_repository.dart';
import '../personal/personal_storage_repository.dart';

class AcademicRead<T> {
  const AcademicRead(
    this.data, {
    required this.offline,
    this.error,
    this.failure,
  });
  final T data;
  final bool offline;
  final String? error;
  final AppException? failure;
}

/// Selects the source, persistent cache and bundled fallback in one place.
abstract interface class AcademicDataRepository {
  Future<AcademicRead<List<CourseMeta>>> list();
  AsyncResult<AcademicRead<CourseDetails>> get(
    CourseMeta course,
    String semester,
  );
}

class AcademicDataRepositoryImpl implements AcademicDataRepository {
  AcademicDataRepositoryImpl(
    this.courses,
    this.storage,
    this.source,
    this.loadAsset,
  );
  final CourseRepository courses;
  final PersonalStorageRepository storage;
  final DataSource source;
  final Future<String> Function(String) loadAsset;
  final Map<String, int> _requests = {};
  String get _prefix => source == DataSource.api
      ? 'flutter_cache'
      : 'flutter_cache_${source.name}';

  Future<AcademicRead<dynamic>> _read(
    String key,
    Future<dynamic> Function() fetch,
    List<String> assets,
  ) async {
    final version = (_requests[key] ?? 0) + 1;
    _requests[key] = version;
    dynamic data;
    var offline = false;
    String? error;
    try {
      data = await fetch();
      if (_requests[key] == version) storage.write(key, jsonEncode(data));
    } catch (failure) {
      data = PersonalStorageRepository.decode(storage.read(key));
      offline = true;
      if (source != DataSource.api) error = '$failure';
    }
    for (final path in assets) {
      if (data != null) break;
      try {
        data = PersonalStorageRepository.decode(await loadAsset(path));
      } catch (_) {
        // A bundled snapshot is optional for courses introduced remotely.
      }
    }
    return AcademicRead(data, offline: offline, error: error);
  }

  @override
  Future<AcademicRead<List<CourseMeta>>> list() async {
    final result = await _read('${_prefix}_courses', courses.list, [
      'assets/data/courses.json',
    ]);
    final raw = result.data;
    final list = raw is List ? raw : asMap(raw)['courses'];
    final data = asList(list)
        .map((e) => CourseMeta.fromJson(asMap(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
    return AcademicRead(
      data,
      offline: result.offline,
      error: data.isEmpty
          ? 'Não foi possível carregar os cursos. Verifique a conexão e o endereço do servidor.'
          : result.error,
    );
  }

  @override
  AsyncResult<AcademicRead<CourseDetails>> get(
    CourseMeta course,
    String semester,
  ) async {
    final id = course.id;
    final key = '${_prefix}_${id}_$semester';
    final version = (_requests[key] ?? 0) + 1;
    _requests[key] = version;
    AppException? failure;
    try {
      final document = await courses.getDocument(
        id,
        semester: semester,
        academicOnly: true,
      );
      final details = AcademicCourseParser.parse(document, course, semester);
      if (_requests[key] == version) {
        storage.write(key, jsonEncode(document));
      }
      return Success(AcademicRead(details, offline: false));
    } catch (cause, stackTrace) {
      failure = AppException(
        'Não foi possível carregar o curso $id.',
        cause: cause,
        stackTrace: stackTrace,
      );
    }
    // Validate each fallback before accepting it; malformed cache cannot hide assets.
    final candidates = <Future<String?> Function()>[
      () async => storage.read(key),
      () => loadAsset('assets/data/${id}_$semester.json'),
      () => loadAsset('assets/data/$id.json'),
    ];
    for (final load in candidates) {
      try {
        final encoded = await load();
        if (encoded == null) continue;
        final raw = jsonDecode(encoded);
        if (raw is! Map) {
          throw const FormatException('Documento do curso inválido.');
        }
        final details = AcademicCourseParser.parse(
          asMap(raw),
          course,
          semester,
          offline: true,
        );
        return Success(
          AcademicRead(
            details,
            offline: true,
            failure: failure,
            error: source == DataSource.api ? null : failure.message,
          ),
        );
      } catch (_) {
        // Keep the original infrastructure/parse failure, including its stack.
      }
    }
    return Failure(failure);
  }
}
