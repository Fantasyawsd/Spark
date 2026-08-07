import 'package:markdown/markdown.dart' as markdown;

import '../domain/paper.dart';
import '../domain/paper_share.dart';

class PaperShareComposer {
  const PaperShareComposer._();

  static PaperSharePayload compose(Paper paper) {
    final firstAuthor = paper.firstAuthor;
    final venue = paper.venue ?? paper.journalReference;
    final authorLine = venue == null ? firstAuthor : '$firstAuthor · $venue';
    final abstractText = _plainText(paper.content.originalAbstractMarkdown);
    final snippet = abstractText.length > 180
        ? '${abstractText.substring(0, 180).trimRight()}…'
        : abstractText;
    final link = paper.paperUrl ?? paper.pdfUrl ?? 'Spark 本地论文，暂无公开链接';
    return PaperSharePayload(
      subject: paper.title,
      text: '${paper.title}\n\n$authorLine\n\n$snippet\n\n$link',
    );
  }

  static String _plainText(String source) {
    final document = markdown.Document(
      extensionSet: markdown.ExtensionSet.gitHubFlavored,
    );
    return document
        .parseLines(source.split('\n'))
        .map((node) => node.textContent)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
