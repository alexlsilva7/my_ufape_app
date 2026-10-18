import '../../../core/api_client.dart';
import '../../../core/models.dart';

/// Resolves the current transport and token for each operation, including refresh.
class ApiRepository {
  ApiRepository(this.api, {this.token});
  final AcademicApi Function() api;
  final Future<String?> Function()? token;

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
  }) async {
    final accessToken = await token?.call();
    return api().request(path, method: method, body: body, token: accessToken);
  }

  Future<JsonMap> object(
    String path, {
    String method = 'GET',
    Object? body,
  }) async => asMap(await request(path, method: method, body: body));

  String segment(String value) => Uri.encodeComponent(value);
}
