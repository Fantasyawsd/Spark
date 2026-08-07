import 'package:url_launcher/url_launcher.dart';

import '../domain/paper_link_service.dart';

class PlatformPaperLinkService implements PaperLinkService {
  const PlatformPaperLinkService();

  @override
  Future<bool> open(Uri uri) => launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
}
