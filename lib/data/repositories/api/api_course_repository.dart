import '../course_details_reader.dart';
import '../../../core/models.dart';
import '../../../domain/repositories/course_repository.dart';
import 'api_repository.dart';

class ApiCourseRepository extends ApiRepository
    with CourseDetailsReader
    implements CourseRepository {
  ApiCourseRepository(super.api, {super.token});

  @override
  Future<JsonMap> list() async {
    final data = await request('/api/courses');
    if (data is! Map || data['courses'] is! List) {
      throw const FormatException('Lista de cursos inválida.');
    }
    return asMap(data);
  }

  @override
  Future<JsonMap> getDocument(
    String id, {
    String? semester,
    bool strict = false,
    bool academicOnly = false,
  }) async {
    final query = Uri(
      queryParameters: {
        'semester': ?semester,
        if (strict) 'strict': 'true',
        if (academicOnly) 'include': 'curriculum,contents,schedule',
      },
    ).query;
    final data = await request(
      '/api/courses/${segment(id)}${query.isEmpty ? '' : '?$query'}',
    );
    if (data is! Map || data['course'] is! Map) {
      throw const FormatException('Dados do curso inválidos.');
    }
    return asMap(data);
  }

  @override
  Future<void> save(JsonMap course) async {
    await request('/api/courses', method: 'POST', body: course);
  }

  @override
  Future<void> updateMetadata(String id, JsonMap metadata) async {
    await request(
      '/api/courses/${segment(id)}/metadata',
      method: 'PATCH',
      body: metadata,
    );
  }

  @override
  Future<void> updateVisibility(String id, JsonMap visibility) async {
    await request(
      '/api/courses/${segment(id)}/visibility',
      method: 'PATCH',
      body: visibility,
    );
  }

  @override
  Future<void> delete(String id) async {
    await request('/api/courses/${segment(id)}', method: 'DELETE');
  }
}
