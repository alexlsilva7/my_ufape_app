enum DataSource {
  local,
  supabase,
  api;

  static DataSource parse(String value) => switch (value.trim().toLowerCase()) {
    'local' => local,
    'supabase' => supabase,
    'api' => api,
    _ => throw ArgumentError('DATA_SOURCE deve ser local, supabase ou api.'),
  };
  static DataSource get environment =>
      parse(const String.fromEnvironment('DATA_SOURCE', defaultValue: 'local'));
}
