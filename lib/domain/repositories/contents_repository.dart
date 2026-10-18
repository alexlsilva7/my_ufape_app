abstract interface class ContentsRepository {
  Future<dynamic> get(String courseId);
  Future<void> save(String courseId, Object data);
}
