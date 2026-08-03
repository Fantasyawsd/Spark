import 'package:flutter_test/flutter_test.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  group('ArxivSubjectCatalog', () {
    test('ships the initial structured subjects with arXiv codes', () {
      expect(
        ArxivSubjectCatalog.initialSubjects
            .map((subject) => subject.code)
            .toList(),
        ['cs.AI', 'cs.CL', 'cs.CV', 'cs.LG'],
      );
      expect(
        ArxivSubjectCatalog.initialSubjects
            .map((subject) => subject.displayName)
            .toList(),
        ['人工智能', '计算与语言', '计算机视觉与模式识别', '机器学习'],
      );
    });
  });

  group('UserPaperChannel', () {
    test('builds stable storage keys by kind and id', () {
      const channel = UserPaperChannel(
        kind: PaperChannelKind.subject,
        id: 'cs.AI',
        displayName: '人工智能',
      );
      expect(channel.storageKey, 'subject:cs.AI');
    });
  });

  group('FixedPaperChannel', () {
    test('keeps the fixed channel order', () {
      expect(
        FixedPaperChannel.values,
        [
          FixedPaperChannel.recommended,
          FixedPaperChannel.following,
          FixedPaperChannel.latest,
        ],
      );
    });
  });
}
