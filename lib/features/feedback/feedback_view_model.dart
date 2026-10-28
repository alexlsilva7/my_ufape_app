import '../../core/academic_context.dart';
import '../../domain/repositories/feedback_repository.dart';

/// Submits feedback with the current academic context attached as metadata.
class FeedbackViewModel {
  FeedbackViewModel(this.repository, this.context, {required this.isLocal});

  final FeedbackRepository repository;
  final AcademicContext context;
  final bool isLocal;

  Future<void> submit({
    required String submissionId,
    required String category,
    required String message,
    required String name,
    required String email,
    required Map<String, Object?> metadata,
  }) => repository.submit({
    'submissionId': submissionId,
    'category': category,
    'message': message,
    'name': name,
    'email': email,
    'metadata': {
      ...metadata,
      'course': context.selectedCourse?.id ?? '',
      'semester': context.selectedSemester,
      'profile': context.selectedProfile,
    },
  });
}
