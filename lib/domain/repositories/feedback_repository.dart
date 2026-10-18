import '../../core/models.dart';

abstract interface class FeedbackRepository {
  Future<void> submit(JsonMap feedback);
  Future<JsonMap> list({
    String category = '',
    String status = '',
    String course = '',
    int offset = 0,
  });
  Future<JsonMap> update(
    String id, {
    required String status,
    required String notes,
  });
}
