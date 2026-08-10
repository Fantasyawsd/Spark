import 'package:flutter_test/flutter_test.dart';
import 'package:spark/spark.dart';

void main() {
  group('ArxivSubjectCatalog', () {
    test('ships the full arXiv cs.* subject catalog in official order', () {
      expect(
        ArxivSubjectCatalog.initialSubjects
            .map((subject) => subject.code)
            .toList(),
        [
          'cs.AI',
          'cs.AR',
          'cs.CC',
          'cs.CE',
          'cs.CG',
          'cs.CL',
          'cs.CR',
          'cs.CV',
          'cs.CY',
          'cs.DB',
          'cs.DC',
          'cs.DL',
          'cs.DM',
          'cs.DS',
          'cs.ET',
          'cs.FL',
          'cs.GL',
          'cs.GR',
          'cs.GT',
          'cs.HC',
          'cs.IR',
          'cs.IT',
          'cs.LG',
          'cs.LO',
          'cs.MA',
          'cs.MM',
          'cs.MS',
          'cs.NA',
          'cs.NE',
          'cs.NI',
          'cs.OH',
          'cs.OS',
          'cs.PF',
          'cs.PL',
          'cs.RO',
          'cs.SC',
          'cs.SD',
          'cs.SE',
          'cs.SI',
          'cs.SY',
        ],
      );
    });

    test('keeps the original subjects with their Chinese display names', () {
      expect(
        ArxivSubjectCatalog.initialSubjects
            .map((subject) => subject.displayName)
            .toList(),
        containsAllInOrder(['人工智能', '计算与语言', '计算机视觉与模式识别', '机器学习']),
      );
    });

    test('subject codes are unique', () {
      final codes = ArxivSubjectCatalog.initialSubjects
          .map((subject) => subject.code)
          .toList();
      expect(codes.toSet().length, codes.length);
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
