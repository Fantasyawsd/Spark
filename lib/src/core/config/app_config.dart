import 'package:flutter/foundation.dart' show kReleaseMode;

import 'app_environment.dart';
import 'feature_flags.dart';

final class AppConfig {
  const AppConfig({
    required this.environment,
    required FeatureFlags features,
    this.paperApiBaseUrl,
  }) : features = environment == AppEnvironment.production
            ? const FeatureFlags()
            : features;

  const AppConfig.production()
      : environment = AppEnvironment.production,
        features = const FeatureFlags(),
        paperApiBaseUrl = null;

  factory AppConfig.fromEnvironment({String? platformFlavor}) {
    return AppConfig.resolve(
      platformFlavor: platformFlavor,
      requestedEnvironment: const String.fromEnvironment('SPARK_ENV'),
      requestedPaperApiBaseUrl: const String.fromEnvironment(
        'SPARK_PAPER_API_BASE_URL',
      ),
    );
  }

  factory AppConfig.resolve({
    String? platformFlavor,
    String? requestedEnvironment,
    String? requestedPaperApiBaseUrl,
  }) {
    final flavor = platformFlavor?.trim();
    final requested = requestedEnvironment?.trim();
    // release 构建固定 production,发布安全不依赖启动传参;
    // debug/profile 运行默认 development,验收时实验功能不再因漏传
    // SPARK_ENV 而静默消失。显式 flavor / SPARK_ENV 仍可覆盖默认值。
    final fallbackEnvironment = kReleaseMode ? 'production' : 'development';
    final environment = AppEnvironment.parse(
      flavor?.isNotEmpty == true
          ? flavor!
          : requested?.isNotEmpty == true
              ? requested!
              : fallbackEnvironment,
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

    final paperApiBaseUrl = environment == AppEnvironment.development
        ? _resolvePaperApiBaseUrl(requestedPaperApiBaseUrl)
        : null;
    final requestedFeatures = FeatureFlags.fromEnvironment(environment);
    final features = environment == AppEnvironment.development
        ? FeatureFlags(
            experimentalCommunity: requestedFeatures.experimentalCommunity,
            experimentalConferenceChannels: true,
            experimentalPdfAi: requestedFeatures.experimentalPdfAi,
          )
        : requestedFeatures;
    return AppConfig(
      environment: environment,
      features: features,
      paperApiBaseUrl: paperApiBaseUrl,
    );
  }

  final AppEnvironment environment;
  final FeatureFlags features;
  final String? paperApiBaseUrl;

  String get applicationTitle => environment.applicationTitle;
  bool get showDebugBanner => !environment.isProduction;
}

String _resolvePaperApiBaseUrl(String? requested) {
  final value = requested?.trim();
  final resolved =
      value?.isNotEmpty == true ? value! : 'http://127.0.0.1:8000/api/v1';
  final uri = Uri.tryParse(resolved);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    throw ArgumentError.value(
      requested,
      'requestedPaperApiBaseUrl',
      'Expected an absolute HTTP(S) Paper API URL.',
    );
  }
  return uri.toString().replaceFirst(RegExp(r'/$'), '');
}
