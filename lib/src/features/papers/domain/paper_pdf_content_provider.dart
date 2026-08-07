import 'paper.dart';
import 'paper_pdf.dart';

abstract interface class PaperPdfContentProvider {
  Future<PaperPdfExtract> load(Paper paper);
}
