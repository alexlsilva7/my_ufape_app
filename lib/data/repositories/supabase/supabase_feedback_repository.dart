import 'dart:convert';

import '../../../core/models.dart';
import '../../../domain/repositories/feedback_repository.dart';
import '../document_feedback_repository.dart';
import 'supabase_data_store.dart';

/// Public submissions retain the server's spam protection; admin reads use RLS.
class SupabaseFeedbackRepository extends DocumentFeedbackRepository {
  SupabaseFeedbackRepository(this._supabase, {required this.submissions})
    : super(_supabase);
  final SupabaseDataStore _supabase;
  final FeedbackRepository submissions;
  @override
  Future<void> submit(JsonMap feedback) => submissions.submit(feedback);
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
    final rows = asList(
      await _supabase.request(
        'site_feedback',
        method: 'PATCH',
        query: {'id': 'eq.${jsonEncode(id)}'},
        body: {
          'status': status,
          'internal_notes': notes,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        prefer: 'return=representation',
      ),
    );
    if (rows.isEmpty) throw const FormatException('Feedback não encontrado.');
    return {'item': asMap(rows.first)};
  }
}
