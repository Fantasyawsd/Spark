import 'paper.dart';
import 'paper_enhancement.dart';
import 'paper_source.dart';

abstract interface class ArxivPaperSource {
  Future<PaperSyncPage> listRecords({
    String? set,
    DateTime? from,
    DateTime? until,
    String? resumptionToken,
  });
}

abstract interface class PaperEnhancementSource {
  Future<PaperEnhancement?> findByArxivId(String arxivId);
}

class PaperSyncState {
  const PaperSyncState({this.lastDatestamp, this.resumptionToken});

  final DateTime? lastDatestamp;
  final String? resumptionToken;
}

abstract interface class PaperSyncStateStore {
  Future<PaperSyncState> read(String source);
  Future<void> write(String source, PaperSyncState state);
}

abstract interface class PaperStore {
  Future<void> upsert(Iterable<Paper> papers);
}
