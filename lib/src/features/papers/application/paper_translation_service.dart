import '../domain/paper.dart';
import '../domain/paper_translation.dart';
import 'paper_content_fingerprint.dart';

export '../domain/paper_translation.dart';

const paperTranslationPromptVersion = 1;
const _fingerprintSeparator = '|spark-translation|';

String paperTranslationInputFingerprint(Paper paper) {
  return paperContentFingerprint(paper, namespace: _fingerprintSeparator);
}

bool isPaperTranslationRecordFresh(PaperTranslationRecord record, Paper paper) {
  return record.paperId == paper.id &&
      record.promptVersion == paperTranslationPromptVersion &&
      record.inputFingerprint == paperTranslationInputFingerprint(paper) &&
      record.markdown.trim().isNotEmpty;
}
