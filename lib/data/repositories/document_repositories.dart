import '../../core/models.dart';
import '../../domain/repositories/contents_repository.dart';
import '../../domain/repositories/curriculum_repository.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../academic_data_store.dart';

class DocumentCurriculumRepository implements CurriculumRepository {
  DocumentCurriculumRepository(this.store);
  final AcademicDataStore store;
  @override
  Future<dynamic> get(String courseId) async => (await store.select(
    'course_curricula',
    filters: {'course_id': courseId},
  )).firstOrNull?['data'];
  @override
  Future<void> save(String courseId, Object data) =>
      store.upsert('course_curricula', {
        'course_id': courseId,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
}

class DocumentContentsRepository implements ContentsRepository {
  DocumentContentsRepository(this.store);
  final AcademicDataStore store;
  @override
  Future<dynamic> get(String courseId) async => (await store.select(
    'course_contents',
    filters: {'course_id': courseId},
  )).firstOrNull?['data'];
  @override
  Future<void> save(String courseId, Object data) =>
      store.upsert('course_contents', {
        'course_id': courseId,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
}

class DocumentScheduleRepository implements ScheduleRepository {
  DocumentScheduleRepository(this.store);
  final AcademicDataStore store;
  @override
  Future<List<String>> semesters(String courseId) async => (await store.select(
    'course_schedules',
    filters: {'course_id': courseId},
  )).map((row) => textOf(row['semester'])).toList()..sort();
  @override
  Future<JsonMap?> get(String courseId, String semester) async =>
      (await store.select(
        'course_schedules',
        filters: {'course_id': courseId, 'semester': semester},
      )).firstOrNull;
  @override
  Future<void> save(
    String courseId,
    String semester,
    List<dynamic> data, {
    Object? extraction,
  }) {
    if (!RegExp(r'^\d{4}\.[12]$').hasMatch(semester)) {
      throw const FormatException('Semestre inválido.');
    }
    return store.upsert('course_schedules', {
      'course_id': courseId,
      'semester': semester,
      'data': data,
      'extraction': extraction,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
