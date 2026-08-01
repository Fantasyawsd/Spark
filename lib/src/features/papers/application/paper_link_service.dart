import 'package:url_launcher/url_launcher.dart';

abstract interface class PaperLinkService {
  Future<bool> open(Uri uri);
}

class PlatformPaperLinkService implements PaperLinkService {
  const PlatformPaperLinkService();

  @override
  Future<bool> open(Uri uri) => launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
}

Uri? validPaperUri(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri;
}
