import '../../../core/models.dart';
import '../../../domain/repositories/feedback_repository.dart';
import 'api_repository.dart';

class ApiFeedbackRepository extends ApiRepository
    implements FeedbackRepository {
  ApiFeedbackRepository(super.api, {super.token});
  @override
  Future<void> submit(JsonMap feedback) async {
    await request('/api/feedback', method: 'POST', body: feedback);
  }

  @override
  Future<JsonMap> list({
    String category = '',
    String status = '',
    String course = '',
    int offset = 0,
  }) {
    final query = Uri(
      queryParameters: {
        'category': category,
        'status': status,
        'course': course,
        'offset': '$offset',
      },
    ).query;
    return object('/api/admin/feedback?$query');
  }

  @override
  Future<JsonMap> update(
    String id, {
    required String status,
    required String notes,
  }) => object(
    '/api/admin/feedback/${segment(id)}',
    method: 'PATCH',
    body: {'status': status, 'internal_notes': notes},
  );
}
