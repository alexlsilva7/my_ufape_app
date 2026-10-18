import '../../core/models.dart';

enum ExtractionMode {
  tree,
  linear,
  schedule;

  static ExtractionMode fromName(String name) => values.byName(name);
}

abstract interface class ExtractionRepository {
  Future<JsonMap> start(JsonMap input);
  Future<JsonMap> get(String token);
  Future<JsonMap> resume(ExtractionMode mode, JsonMap input);
}
