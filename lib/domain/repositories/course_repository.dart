import 'package:result_dart/result_dart.dart';

import '../entities/course_details.dart';
import '../../core/models.dart';

abstract interface class CourseRepository {
  Future<JsonMap> list();
  AsyncResult<CourseDetails> get(
    String id, {
    String? semester,
    bool strict = false,
    bool academicOnly = false,
  });

  /// Original documents for administration, export and persistent source cache.
  Future<JsonMap> getDocument(
    String id, {
    String? semester,
    bool strict = false,
    bool academicOnly = false,
  });
  Future<void> save(JsonMap course);
  Future<void> updateMetadata(String id, JsonMap metadata);
  Future<void> updateVisibility(String id, JsonMap visibility);
  Future<void> delete(String id);
}
