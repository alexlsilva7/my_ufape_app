import 'dart:math' as math;

import '../core/models.dart';

class CompletionIdentity {
  static String of(Object item) {
    String? code, profile;
    String id;
    if (item is Subject) {
      final selection = item.electiveSelection;
      code = selection?.source == 'catalog' ? selection?.code : item.code;
      id = selection?.source == 'catalog'
          ? selection?.subjectId ?? item.id
          : item.id;
      profile = item.profile;
    } else if (item is Discipline) {
      code = item.code;
      id = item.id;
      profile = item.profile;
    } else {
      return '';
    }
    if (code?.trim().isNotEmpty == true) return code!.trim().toUpperCase();
    return 'id:${Uri.encodeComponent(profile?.trim().isNotEmpty == true ? profile! : 'unassigned')}:${Uri.encodeComponent(id)}';
  }
}

class AcademicProgressCalculator {
  static MatrixProgress calculate({
    required String courseId,
    required CurriculumProfile? profile,
    required List<Subject> counted,
    required bool Function(Object) isCompleted,
    required double acexHours,
    required double accHours,
  }) {
    final p = profile;
    double mandatory = 0, optative = 0;
    int count = 0;
    for (final s in counted) {
      if (!isCompleted(s)) continue;
      count++;
      if (s.isElective) {
        optative += s.displayHours;
      } else {
        mandatory += s.displayHours;
      }
    }
    final eal =
        courseId == 'eal' ||
        courseId == 'engenharia-de-alimentos' ||
        (profile?.id ?? '').startsWith('EAL');
    final acexTarget = p?.acexHours ?? 0;
    final accTarget = p?.accHours ?? 0;
    final acex = math.min(
      acexHours,
      acexTarget > 0
          ? acexTarget
          : eal
          ? 390.0
          : 0.0,
    );
    final acc = math.min(
      accHours,
      accTarget > 0
          ? accTarget
          : eal
          ? 120.0
          : 0.0,
    );
    return MatrixProgress(
      doneHours: mandatory + optative + acex + acc,
      totalHours: p?.totalHours ?? 0,
      mandatoryHours: mandatory,
      optativeHours: optative,
      acexHours: acex,
      accHours: acc,
      completedCount: count,
      totalCount: counted.length,
    );
  }
}

class ScheduleConflicts {
  static Discipline? find(
    Iterable<Discipline> selected,
    Discipline discipline,
  ) {
    for (final other in selected) {
      if (other.id == discipline.id) continue;
      if (discipline.sessions.any((a) => other.sessions.any(a.overlaps))) {
        return other;
      }
    }
    return null;
  }
}

class AcademicGrades {
  static String? normalize(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return '';
    final grade = double.tryParse(normalized);
    return grade != null && grade.isFinite && grade >= 0 && grade <= 10
        ? normalized
        : null;
  }
}

class ElectiveAssignments {
  static bool isAssigned(
    Iterable<Subject> subjects,
    ElectiveSelection selection, {
    String? excluding,
  }) =>
      selection.source == 'catalog' &&
      subjects.any(
        (s) =>
            s.id != excluding &&
            (s.electiveSelection?.identity == selection.identity ||
                s.isElective &&
                    !s.isGenericElective &&
                    (s.period ?? 0) > 0 &&
                    'code:${normalized(s.code ?? '')}' == selection.identity),
      );
}
