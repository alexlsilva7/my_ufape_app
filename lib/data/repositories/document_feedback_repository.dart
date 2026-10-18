import '../../core/models.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../academic_data_store.dart';

class DocumentFeedbackRepository implements FeedbackRepository {
  DocumentFeedbackRepository(this.store);
  final AcademicDataStore store;
  @override
  Future<void> submit(JsonMap feedback) async {
    final id = textOf(feedback['submissionId']);
    final message = textOf(feedback['message']).trim();
    if (id.isEmpty || message.length < 10 || message.length > 3000) {
      throw const FormatException('Feedback inválido.');
    }
    if ((await store.select('site_feedback', filters: {'id': id})).isNotEmpty) {
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await store.upsert('site_feedback', {
      'id': id,
      'category': feedback['category'],
      'message': message,
      'name': feedback['name'],
      'email': feedback['email'],
      'metadata': feedback['metadata'] ?? {},
      'status': 'new',
      'internal_notes': '',
      'created_at': now,
      'updated_at': now,
    });
  }

  @override
  Future<JsonMap> list({
    String category = '',
    String status = '',
    String course = '',
    int offset = 0,
  }) async {
    if (offset < 0) throw const FormatException('Página inválida.');
    final rows =
        (await store.select('site_feedback'))
            .where(
              (row) =>
                  (category.isEmpty || row['category'] == category) &&
                  (status.isEmpty || row['status'] == status) &&
                  (course.isEmpty ||
                      asMap(row['metadata'])['course'] == course),
            )
            .toList()
          ..sort((a, b) {
            final date = textOf(b['created_at'])
                .compareTo(textOf(a['created_at']));
            return date == 0
                ? textOf(a['id']).compareTo(textOf(b['id']))
                : date;
          });
    return {'items': rows.skip(offset).take(25).toList(), 'total': rows.length};
  }

  @override
  Future<JsonMap> update(
    String id, {
    required String status,
    required String notes,
  }) async {
    if (![
          'new',
          'reviewing',
          'planned',
          'resolved',
          'archived',
        ].contains(status) ||
        notes.length > 5000) {
      throw const FormatException('Atualização inválida.');
    }
    final previous = (await store.select(
      'site_feedback',
      filters: {'id': id},
    )).firstOrNull;
    if (previous == null) {
      throw const FormatException('Feedback não encontrado.');
    }
    final row = {
      ...previous,
      'status': status,
      'internal_notes': notes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await store.upsert('site_feedback', row);
    return {'item': row};
  }
}
