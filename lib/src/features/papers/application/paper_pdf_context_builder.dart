import '../domain/paper_pdf.dart';

/// 把论文 PDF 分块裁剪成可注入 systemPrompt 的「全文引用」文本。
///
/// 裁剪规则：
/// - 按分块顺序取用，直到接近 [maxChars] 预算，防止上下文溢出；
/// - 每个分块保留页码/章节标注，供模型做可追溯引用；
/// - 注入文本只在用户开启「读取全文」时使用，不作为聊天消息展示。
class PaperPdfContextBuilder {
  const PaperPdfContextBuilder._();

  static const defaultMaxChars = 6000;

  static String buildContextChunk(
    List<PaperPdfChunk> chunks, {
    int maxChars = defaultMaxChars,
  }) {
    final buffer = StringBuffer('以下是论文全文的分块内容（按需引用，标注出处）：');
    var used = 0;
    for (final chunk in chunks) {
      final block = '\n\n【${chunk.referenceLabel}】\n${chunk.text}';
      if (used + block.length > maxChars) break;
      buffer.write(block);
      used += block.length;
    }
    return buffer.toString();
  }
}
