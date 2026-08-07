import 'dart:convert';

import '../domain/paper.dart';
import '../domain/paper_translation.dart';

export '../domain/paper_translation.dart';

const paperTranslationPromptVersion = 1;
const _fingerprintSeparator = '|spark-translation|';

String paperTranslationInputFingerprint(Paper paper) {
  final bytes = utf8.encode(
    '${paper.title.trim()}$_fingerprintSeparator'
    '${paper.content.originalAbstractMarkdown.trim()}',
  );
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

bool isPaperTranslationRecordFresh(
  PaperTranslationRecord record,
  Paper paper,
) {
  return record.paperId == paper.id &&
      record.promptVersion == paperTranslationPromptVersion &&
      record.inputFingerprint == paperTranslationInputFingerprint(paper) &&
      record.markdown.trim().isNotEmpty;
}
