import 'app_environment.dart';
import 'feature_flags.dart';

final class AppConfig {
  const AppConfig({required this.environment, required this.features});

  const AppConfig.production()
      : environment = AppEnvironment.production,
        features = const FeatureFlags();

  factory AppConfig.fromEnvironment() {
    final environment = AppEnvironment.parse(
      const String.fromEnvironment('PAPERFLOW_ENV', defaultValue: 'production'),
    );
    return AppConfig(
      environment: environment,
      features: FeatureFlags.fromEnvironment(environment),
    );
  }

  final AppEnvironment environment;
  final FeatureFlags features;

  String get applicationTitle => environment.applicationTitle;
  bool get showDebugBanner => !environment.isProduction;
}
