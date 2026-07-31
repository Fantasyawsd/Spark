import '../domain/paper.dart';
import '../domain/paper_sync_ports.dart';
import 'arxiv_paper_mapper.dart';

class ArxivPaperSyncService {
  ArxivPaperSyncService({
    required this.metadataSource,
    required this.stateStore,
    required this.paperStore,
    this.enhancementSource,
  });

  final ArxivMetadataSource metadataSource;
  final PaperEnhancementSource? enhancementSource;
  final PaperSyncStateStore stateStore;
  final PaperStore paperStore;

  Future<int> sync({String? set, DateTime? until}) async {
    final state = await stateStore.read('arxiv-oai');
    var token = state.resumptionToken;
    var count = 0;
    DateTime? latest = state.lastDatestamp;

    do {
      final page = await metadataSource.listRecords(
        set: set,
        from: token == null ? state.lastDatestamp : null,
        until: token == null ? until : null,
        resumptionToken: token,
      );
      final papers = <PaperRecord>[];
      for (final metadata in page.records) {
        var record = metadata.toPaperRecord();
        final enhancement = await enhancementSource?.findByArxivId(
          metadata.normalizedId,
        );
        if (enhancement != null) {
          record = record.copyWithEnhancement(enhancement);
        }
        papers.add(record);
        if (latest == null || metadata.updatedAt.isAfter(latest)) {
          latest = metadata.updatedAt;
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
