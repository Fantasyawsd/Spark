import 'package:flutter_test/flutter_test.dart';
import 'package:spark/src/features/papers/application/paper_sync_service.dart';
import 'package:spark/src/features/papers/domain/paper.dart';
import 'package:spark/src/features/papers/domain/paper_enhancement.dart';
import 'package:spark/src/features/papers/domain/paper_source.dart';
import 'package:spark/src/features/papers/domain/paper_sync_ports.dart';

void main() {
  test(
    'sync service coordinates ports without concrete HTTP clients',
    () async {
      final store = _MemoryPaperStore();
      final stateStore = _MemorySyncStateStore();
      final service = ArxivPaperSyncService(
        paperSource: _FakePaperSource(),
        enhancementSource: _FakeEnhancementSource(),
        stateStore: stateStore,
        paperStore: store,
      );

      final count = await service.sync(set: 'cs:cs:AI');

      expect(count, 1);
      expect(store.papers.single.title, 'Imported paper');
      expect(store.papers.single.metrics.citations, 42);
      expect(stateStore.state.lastDatestamp, DateTime.utc(2024, 1, 2));
    },
  );
}

class _FakePaperSource implements ArxivPaperSource {
  @override
  Future<PaperSyncPage> listRecords({
    String? set,
    DateTime? from,
    DateTime? until,
    String? resumptionToken,
  }) async {
    return PaperSyncPage(
      papers: [
        Paper(
          id: '2401.00001',
          title: 'Imported paper',
          authors: const ['Alice Smith'],
          subjects: const ['cs.AI'],
          primarySubject: 'cs.AI',
          abstractText: 'An imported abstract.',
          chineseAbstractMarkdown: '中文摘要尚未生成。',
          readMinutes: 1,
          arxivId: '2401.00001',
          publishedAt: DateTime.utc(2024, 1, 1),
          updatedAt: DateTime.utc(2024, 1, 2),
          source: 'arxiv',
        ),
      ],
    );
  }
}

class _FakeEnhancementSource implements PaperEnhancementSource {
  @override
  Future<PaperEnhancement?> findByArxivId(String arxivId) async {
    return const PaperEnhancement(citationCount: 42);
  }
}

class _MemoryPaperStore implements PaperStore {
  final papers = <Paper>[];

  @override
  Future<void> upsert(Iterable<Paper> values) async {
    papers
      ..clear()
      ..addAll(values);
  }
}

class _MemorySyncStateStore implements PaperSyncStateStore {
  PaperSyncState state = const PaperSyncState();

  @override
  Future<PaperSyncState> read(String source) async => state;

  @override
  Future<void> write(String source, PaperSyncState value) async {
    state = value;
  }
}
