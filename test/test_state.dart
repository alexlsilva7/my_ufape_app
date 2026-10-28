import 'package:my_ufape/app/app_repositories.dart';
import 'package:my_ufape/config/dependencies.dart';
import 'package:my_ufape/core/api_client.dart';
import 'package:my_ufape/core/app_state.dart';

AppState createAppState({
  AcademicApi? api,
  AppRepositories? repositories,
  Future<String> Function(String)? assetLoader,
}) {
  assert(api == null || repositories == null);
  return setupDependencies(
    repositories:
        repositories ?? AppRepositories(api: api, assetLoader: assetLoader),
    assetLoader: assetLoader,
  ).state;
}
