abstract interface class CurriculumRepository {
  Future<dynamic> get(String courseId);
  Future<void> save(String courseId, Object data);
}
