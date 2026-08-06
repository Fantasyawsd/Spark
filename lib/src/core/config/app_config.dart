import 'app_environment.dart';
import 'feature_flags.dart';

final class AppConfig {
  const AppConfig({required this.environment, required this.features});

  const AppConfig.production()
      : environment = AppEnvironment.production,
        features = const FeatureFlags();

  factory AppConfig.fromEnvironment({String? platformFlavor}) {
    return AppConfig.resolve(
      platformFlavor: platformFlavor,
      requestedEnvironment: const String.fromEnvironment('SPARK_ENV'),
    );
  }

  factory AppConfig.resolve({
    String? platformFlavor,
    String? requestedEnvironment,
  }) {
    final flavor = platformFlavor?.trim();
    final requested = requestedEnvironment?.trim();
    final environment = AppEnvironment.parse(
      flavor?.isNotEmpty == true
          ? flavor!
          : requested?.isNotEmpty == true
              ? requested!
              : 'production',
    );

    if (flavor?.isNotEmpty == true && requested?.isNotEmpty == true) {
      final requestedValue = AppEnvironment.parse(requested!);
      if (requestedValue != environment) {
        throw StateError(
          'Android flavor "$flavor" does not match '
          'SPARK_ENV "$requested".',
        );
      }
    }

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
