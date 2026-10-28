import 'package:result_dart/result_dart.dart';

import '../../core/models.dart';
import '../../core/exceptions/app_exception.dart';
import '../../domain/entities/course_details.dart';
import '../../domain/repositories/course_repository.dart';
import '../parsers/academic_course_parser.dart';

/// Shared typed boundary for API, local and Supabase document sources.
mixin CourseDetailsReader implements CourseRepository {
  @override
  AsyncResult<CourseDetails> get(
    String id, {
    String? semester,
    bool strict = false,
    bool academicOnly = false,
  }) async {
    try {
      final document = await getDocument(
        id,
        semester: semester,
        strict: strict,
        academicOnly: academicOnly,
      );
      return Success(
        AcademicCourseParser.parse(
          document,
          CourseMeta.fromJson(asMap(document['course'])),
          semester ?? '2026.1',
        ),
      );
    } catch (cause, stackTrace) {
      return Failure(
        AppException(
          'Não foi possível carregar o curso $id.',
          cause: cause,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
