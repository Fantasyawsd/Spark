import '../domain/paper.dart';

class PaperSharePayload {
  const PaperSharePayload({required this.subject, required this.text});

  final String subject;
  final String text;
}

enum PaperShareResult { shared, copied, cancelled }

abstract interface class PaperShareService {
  Future<PaperShareResult> share(PaperSharePayload payload);
}

class PaperShareException implements Exception {
  const PaperShareException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

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

  static String _plainText(String markdown) {
    return markdown
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'[*_~0#>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
