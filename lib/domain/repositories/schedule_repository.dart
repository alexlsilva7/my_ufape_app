import '../../core/models.dart';

abstract interface class ScheduleRepository {
  Future<List<String>> semesters(String courseId);
  Future<JsonMap?> get(String courseId, String semester);
  Future<void> save(
    String courseId,
    String semester,
    List<dynamic> data, {
    Object? extraction,
  });
}
