import 'package:flutter/material.dart';

import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../domain/paper.dart';
import '../../domain/paper_link_service.dart';

class PaperPdfButton extends StatelessWidget {
  const PaperPdfButton({super.key, required this.paper, required this.onOpen});

  final Paper paper;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final uri = validPaperUri(paper.pdfUrl) ?? validPaperUri(paper.paperUrl);
    if (uri == null) return const SizedBox.shrink();
    final hasPdf = validPaperUri(paper.pdfUrl) != null;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const ValueKey('paper-open-link'),
        onPressed: () => onOpen(uri),
        style: TextButton.styleFrom(
          foregroundColor: SparkColors.of(context).ink,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(
          hasPdf ? Icons.picture_as_pdf_outlined : Icons.open_in_new_rounded,
          size: 18,
        ),
        label: Text(
          hasPdf ? '查看 PDF' : '查看论文',
          style: const TextStyle(
            fontSize: SparkFontSizes.bodySmall,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
