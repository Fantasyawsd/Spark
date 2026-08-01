enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'development' || 'dev' => development,
      'staging' || 'stage' || 'beta' => staging,
      'production' || 'prod' => production,
      _ => throw ArgumentError.value(
          value,
          'value',
          'Expected development, staging, or production.',
        ),
    };
  }

  String get applicationTitle => switch (this) {
        development => 'PaperFlow Dev',
        staging => 'PaperFlow Beta',
        production => 'PaperFlow',
      };

  bool get isProduction => this == production;
}
