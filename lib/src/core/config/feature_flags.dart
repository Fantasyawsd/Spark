import 'app_environment.dart';

final class FeatureFlags {
  const FeatureFlags({
    this.experimentalCommunity = false,
    this.experimentalConferenceChannels = false,
    this.experimentalPdfAi = false,
  });

  factory FeatureFlags.fromEnvironment(AppEnvironment environment) {
    const requested = FeatureFlags(
      experimentalCommunity: bool.fromEnvironment(
        'PAPERFLOW_FEATURE_COMMUNITY',
      ),
      experimentalConferenceChannels: bool.fromEnvironment(
        'PAPERFLOW_FEATURE_CONFERENCE_CHANNELS',
      ),
      experimentalPdfAi: bool.fromEnvironment('PAPERFLOW_FEATURE_PDF_AI'),
    );
    return requested.allowedFor(environment);
  }

  final bool experimentalCommunity;
  final bool experimentalConferenceChannels;
  final bool experimentalPdfAi;

  FeatureFlags allowedFor(AppEnvironment environment) {
    if (environment.isProduction) return const FeatureFlags();
    return this;
  }
}
