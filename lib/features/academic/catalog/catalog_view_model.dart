import 'package:flutter/foundation.dart';

import '../../../core/academic_context.dart';
import '../../../core/models.dart';
import '../../../domain/entities/course_details.dart';

/// Presentation state for the published catalog, independent of student progress.
class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel(this.context) {
    context.addListener(_sourceChanged);
  }

  final AcademicContext context;
  bool _disposed = false;

  List<Subject> get catalogSubjects => context.catalogSubjects;
  String get selectedProfile => context.selectedProfile;
  bool get loading => context.loading;
  CourseDetails? get courseDetails => context.courseDetails;

  List<Subject>? _indexedCatalog;
  List<String> _profiles = const [];
  List<int> _periods = const [];
  Map<Subject, String> _searchTexts = {};
  void _indexCatalog() {
    if (listEquals(_indexedCatalog, catalogSubjects)) return;
    _indexedCatalog = List.unmodifiable(catalogSubjects);
    _profiles = List.unmodifiable(
      catalogSubjects
          .map((s) => s.profile)
          .whereType<String>()
          .where((p) => p.isNotEmpty && normalized(p) != 'optativa')
          .toSet()
          .toList()
        ..sort(),
    );
    _periods = List.unmodifiable(
      catalogSubjects.map((s) => s.period).whereType<int>().toSet().toList()
        ..sort(),
    );
    _searchTexts = {
      for (final s in catalogSubjects)
        s: normalized('${s.name} ${s.code ?? ''} ${s.profile ?? ''}'),
    };
  }

  List<String> get profiles {
    _indexCatalog();
    return _profiles;
  }

  List<int> get periods {
    _indexCatalog();
    return _periods;
  }

  List<Subject> filteredSubjects({
    String query = '',
    String type = 'all',
    int? period,
  }) {
    final q = normalized(query);
    final singleProfile = profiles.length <= 1;
    return catalogSubjects
        .where(
          (subject) =>
              _searchTexts[subject]!.contains(q) &&
              (period == null || subject.period == period) &&
              (selectedProfile == 'all' ||
                  singleProfile ||
                  subject.isCatalogElective ||
                  subject.profile == selectedProfile) &&
              (type == 'all' ||
                  (type == 'optativa'
                      ? subject.isCatalogElective
                      : !subject.isCatalogElective)),
        )
        .toList();
  }

  Future<void> selectProfile(String profile) => context.selectProfile(profile);

  void _sourceChanged() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    context.removeListener(_sourceChanged);
    super.dispose();
  }
}
