import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/src/core/config/app_config.dart';
import 'package:paperflow/src/core/config/app_environment.dart';
import 'package:paperflow/src/core/config/app_version.dart';
import 'package:paperflow/src/core/config/feature_flags.dart';

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

    expect(config.applicationTitle, 'PaperFlow');
    expect(config.showDebugBanner, isFalse);
    expect(AppVersion.current.display, '0.1.0 (1)');
  });
}
