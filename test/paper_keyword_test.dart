import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/chat/application/chat_ai_service.dart';
import 'package:spark/src/features/chat/domain/chat_context.dart';
import 'package:spark/src/features/chat/domain/chat_message.dart';
import 'package:spark/src/features/papers/application/paper_keyword_controller.dart';
import 'package:spark/src/features/papers/application/paper_keyword_service.dart';
import 'package:spark/src/features/papers/data/in_memory_paper_keyword_repository.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_keyword_record.dart';

void main() {
  group('PaperKeywordParser', () {
    test('parses fenced JSON and removes duplicates', () {
      final keywords = PaperKeywordParser.parse(
        '```json\n["LLM", "llm", "RAG", "Agents", "Evaluation", "Safety"]\n```',
      );

      expect(keywords, ['LLM', 'RAG', 'Agents', 'Evaluation', 'Safety']);
    });

    test('rejects keyword counts outside 5 to 12', () {
      expect(
        () => PaperKeywordParser.parse('["a", "b", "c", "d"]'),
        throwsA(isA<PaperKeywordGenerationException>()),
      );
    });
  });

  test('fingerprint changes with title or Abstract', () {
    final first = _paper(title: 'First');
    final second = _paper(title: 'Second');

    expect(
      paperKeywordInputFingerprint(first),
      isNot(paperKeywordInputFingerprint(second)),
    );
  });

  test('controller only restores a fresh generated record', () async {
    final repository = InMemoryPaperKeywordRepository();
    final paper = _paper();
    await repository.save(
      PaperKeywordRecord(
        paperId: paper.id,
        keywords: const ['a', 'b', 'c', 'd', 'e'],
        inputFingerprint: 'stale',
        promptVersion: paperKeywordPromptVersion,
        generatedAt: DateTime.utc(2026, 8, 6),
      ),
    );
    final controller = PaperKeywordController(
      paper: paper,
      service: _FakeAiService('[]'),
      repository: repository,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.keywords, isEmpty);
  });

  test('controller generates and persists normalized keywords', () async {
    final repository = InMemoryPaperKeywordRepository();
    final paper = _paper();
    final controller = PaperKeywordController(
      paper: paper,
      service: _FakeAiService('["A", "B", "C", "D", "E"]'),
      repository: repository,
    );
    addTearDown(controller.dispose);

    await controller.generate();

    expect(controller.keywords, ['A', 'B', 'C', 'D', 'E']);
    final stored = await repository.load(paper.id);
    expect(stored, isNotNull);
    expect(isPaperKeywordRecordFresh(stored!, paper), isTrue);
  });
}

Paper _paper({String title = 'Paper title'}) => Paper(
      id: 'paper-1',
      title: title,
      authors: const ['Author'],
      abstractText: 'An Abstract about methods and evaluation.',
      chineseAbstractMarkdown: '',
      readMinutes: 3,
    );

class _FakeAiService implements ChatAiService {
  const _FakeAiService(this.response);

  final String response;

  @override
  Future<String> answer({
    required ChatContext context,
    required List<ChatMessage> conversation,
  }) async {
    return response;
  }
}
