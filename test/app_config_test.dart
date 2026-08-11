import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/core/config/app_config.dart';
import 'package:spark/src/core/config/app_environment.dart';
import 'package:spark/src/core/config/app_version.dart';
import 'package:spark/src/core/config/feature_flags.dart';

void main() {
  test('environment aliases resolve to stable channels', () {
    expect(AppEnvironment.parse('dev'), AppEnvironment.development);
    expect(AppEnvironment.parse('beta'), AppEnvironment.staging);
    expect(AppEnvironment.parse('prod'), AppEnvironment.production);
    expect(() => AppEnvironment.parse('preview'), throwsArgumentError);
  });

  test('production strips experimental feature flags', () {
    const requested = FeatureFlags(
      experimentalCommunity: true,
      experimentalConferenceChannels: true,
      experimentalPdfAi: true,
    );

    final production = requested.allowedFor(AppEnvironment.production);
    final development = requested.allowedFor(AppEnvironment.development);

    expect(production.experimentalCommunity, isFalse);
    expect(production.experimentalConferenceChannels, isFalse);
    expect(production.experimentalPdfAi, isFalse);
    expect(development.experimentalCommunity, isTrue);
    expect(development.experimentalConferenceChannels, isTrue);
    expect(development.experimentalPdfAi, isTrue);
  });

  test('production config and version expose user-facing metadata', () {
    const config = AppConfig.production();
    const version = AppVersion(name: '1.2.3', buildNumber: 42);

    expect(config.applicationTitle, 'Spark');
    expect(config.showDebugBanner, isFalse);
    expect(version.display, '1.2.3 (42)');
  });

  test('public config construction cannot enable production experiments', () {
    const config = AppConfig(
      environment: AppEnvironment.production,
      features: FeatureFlags(
        experimentalCommunity: true,
        experimentalConferenceChannels: true,
        experimentalPdfAi: true,
      ),
    );

    expect(config.features.experimentalCommunity, isFalse);
    expect(config.features.experimentalConferenceChannels, isFalse);
    expect(config.features.experimentalPdfAi, isFalse);
  });

  test('platform flavor and requested environment must match', () {
    final development = AppConfig.resolve(
      platformFlavor: 'development',
      requestedEnvironment: 'dev',
    );

    expect(development.environment, AppEnvironment.development);
    expect(development.paperApiBaseUrl, 'http://127.0.0.1:8000/api/v1');
    expect(
      () => AppConfig.resolve(
        platformFlavor: 'production',
        requestedEnvironment: 'development',
      ),
      throwsStateError,
    );
  });

  test('Paper API is development-only and supports an explicit base URL', () {
    final development = AppConfig.resolve(
      requestedEnvironment: 'development',
      requestedPaperApiBaseUrl: 'http://localhost:9000/api/v1/',
    );
    final staging = AppConfig.resolve(
      requestedEnvironment: 'staging',
      requestedPaperApiBaseUrl: 'http://localhost:9000/api/v1',
    );

    expect(development.paperApiBaseUrl, 'http://localhost:9000/api/v1');
    expect(staging.paperApiBaseUrl, isNull);
    expect(
      () => AppConfig.resolve(
        requestedEnvironment: 'development',
        requestedPaperApiBaseUrl: 'localhost:8000',
      ),
      throwsArgumentError,
    );
  });
}
