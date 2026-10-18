import '../document_course_repository.dart';

class LocalCourseRepository extends DocumentCourseRepository {
  LocalCourseRepository(
    super.store, {
    required super.curricula,
    required super.contents,
    required super.schedules,
  });
}
