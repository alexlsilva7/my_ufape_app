import '../document_course_repository.dart';

class SupabaseCourseRepository extends DocumentCourseRepository {
  SupabaseCourseRepository(
    super.store, {
    required super.curricula,
    required super.contents,
    required super.schedules,
  });
}
