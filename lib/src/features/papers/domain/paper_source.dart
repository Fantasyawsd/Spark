import 'paper.dart';

class PaperSyncPage {
  PaperSyncPage({
    required Iterable<Paper> papers,
    this.resumptionToken,
  }) : papers = List.unmodifiable(papers);

  final List<Paper> papers;
  final String? resumptionToken;
}
