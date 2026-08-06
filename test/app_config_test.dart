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

  test('platform flavor and requested environment must match', () {
    final development = AppConfig.resolve(
      platformFlavor: 'development',
      requestedEnvironment: 'dev',
    );

    expect(development.environment, AppEnvironment.development);
    expect(
      () => AppConfig.resolve(
        platformFlavor: 'production',
        requestedEnvironment: 'development',
      ),
      throwsStateError,
    );
  });
}
