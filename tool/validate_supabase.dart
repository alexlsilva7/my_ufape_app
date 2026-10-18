import 'dart:convert';
import 'dart:io';

import 'package:my_ufape/core/models.dart';
import 'package:my_ufape/data/repositories/supabase/supabase_contents_repository.dart';
import 'package:my_ufape/data/repositories/supabase/supabase_course_repository.dart';
import 'package:my_ufape/data/repositories/supabase/supabase_curriculum_repository.dart';
import 'package:my_ufape/data/repositories/supabase/supabase_data_store.dart';
import 'package:my_ufape/data/repositories/supabase/supabase_schedule_repository.dart';

/// Read-only smoke test through the same repositories used by the app.
Future<void> main(List<String> args) async {
  final config = asMap(
    jsonDecode(await File('.env.release.json').readAsString()),
  );
  final courseId = args.isEmpty ? 'bcc' : args[0];
  final semester = args.length > 1 ? args[1] : '2026.2';
  final store = SupabaseDataStore(
    url: textOf(config['SUPABASE_URL']),
    key: textOf(config['SUPABASE_PUBLISHABLE_KEY']),
  );
  try {
    final courses = SupabaseCourseRepository(
      store,
      curricula: SupabaseCurriculumRepository(store),
      contents: SupabaseContentsRepository(store),
      schedules: SupabaseScheduleRepository(store),
    );
    final catalog = await courses.list();
    if (asList(catalog['courses']).isEmpty) {
      throw StateError('A lista de cursos está vazia.');
    }
    final data = await courses.get(courseId, semester: semester, strict: true);
    final curriculum = asMap(data['curriculum']);
    final profiles = asList(curriculum['profiles']);
    final subjects = asList(curriculum['subjects']);
    final contents = asMap(data['contents']);
    final disciplines = asList(contents['disciplinas']);
    final schedule = asList(data['schedule']);
    if ((profiles.isEmpty && subjects.isEmpty) ||
        disciplines.isEmpty ||
        schedule.isEmpty ||
        data['resolvedSemester'] != semester) {
      throw StateError(
        'Resposta acadêmica incompleta para $courseId/$semester.',
      );
    }
    stdout.writeln(
      'Supabase sem login: ${asList(catalog['courses']).length} cursos',
    );
    stdout.writeln(
      '$courseId/$semester: ${profiles.length} perfis, '
      '${subjects.length} disciplinas, ${disciplines.length} ementas, '
      '${schedule.length} ofertas',
    );
    stdout.writeln('Leitura direta pelos repositórios do app: OK');
  } finally {
    store.dispose();
  }
}
