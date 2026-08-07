import '../domain/paper.dart';
import '../domain/paper_enhancement.dart';
import '../domain/paper_sync_ports.dart';

class ArxivPaperSyncService {
  ArxivPaperSyncService({
    required this.paperSource,
    required this.stateStore,
    required this.paperStore,
    this.enhancementSource,
  });

  final ArxivPaperSource paperSource;
  final PaperEnhancementSource? enhancementSource;
  final PaperSyncStateStore stateStore;
  final PaperStore paperStore;

  Future<int> sync({String? set, DateTime? until}) async {
    final state = await stateStore.read('arxiv-oai');
    var token = state.resumptionToken;
    var count = 0;
    DateTime? latest = state.lastDatestamp;

    do {
      final page = await paperSource.listRecords(
        set: set,
        from: token == null ? state.lastDatestamp : null,
        until: token == null ? until : null,
        resumptionToken: token,
      );
      final papers = <Paper>[];
      for (final paper in page.papers) {
        var record = paper;
        final enhancement = await enhancementSource?.findByArxivId(
          paper.arxivId ?? paper.id,
        );
        if (enhancement != null) {
          record = record.applyEnhancement(enhancement);
        }
        papers.add(record);
        final updatedAt = paper.updatedAt;
        if (updatedAt != null &&
            (latest == null || updatedAt.isAfter(latest))) {
          latest = updatedAt;
        }
      }
      if (papers.isNotEmpty) await paperStore.upsert(papers);
      count += papers.length;
      token = page.resumptionToken;
      await stateStore.write(
        'arxiv-oai',
        PaperSyncState(lastDatestamp: latest, resumptionToken: token),
      );
    } while (token != null);
    return count;
  }
}
