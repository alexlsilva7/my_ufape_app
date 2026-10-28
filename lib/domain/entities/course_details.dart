import '../../core/models.dart';

/// Published course definitions, independent of their API or asset JSON format.
class CourseDetails {
  CourseDetails({
    required this.course,
    required this.semester,
    required List<CurriculumProfile> profiles,
    required List<Discipline> offerings,
    required List<Subject> catalog,
    required List<CourseContent> contents,
    this.activeProfileId,
    this.catalogExportedAt,
  }) : profiles = List.unmodifiable(profiles),
       offerings = List.unmodifiable(offerings),
       catalog = List.unmodifiable(catalog),
       contents = List.unmodifiable(contents);
  final CourseMeta course;
  final String semester;
  final List<CurriculumProfile> profiles;
  final List<Discipline> offerings;
  final List<Subject> catalog;
  final List<CourseContent> contents;
  final String? activeProfileId;
  final DateTime? catalogExportedAt;

  CourseContent? contentFor(Subject subject) => contents
      .where(
        (content) =>
            (content.code.isNotEmpty &&
                normalized(content.code) ==
                    normalized(subject.displayCode ?? '')) ||
            normalized(content.name) == normalized(subject.displayName),
      )
      .firstOrNull;
}

class CourseContent {
  const CourseContent({
    required this.code,
    required this.name,
    required this.description,
    required this.program,
  });
  final String code, name, description, program;
}
