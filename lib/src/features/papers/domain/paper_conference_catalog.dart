class PaperConference {
  const PaperConference({required this.id, required this.displayName});

  /// Stable Paper API venue identifier.
  final String id;
  final String displayName;
}

/// Conferences backed by the local arXiv venue enrichment dataset.
class PaperConferenceCatalog {
  const PaperConferenceCatalog._();

  static const List<PaperConference> conferences = [
    PaperConference(id: 'NeurIPS', displayName: 'NeurIPS'),
    PaperConference(id: 'CVPR', displayName: 'CVPR'),
    PaperConference(id: 'ICML', displayName: 'ICML'),
    PaperConference(id: 'ICLR', displayName: 'ICLR'),
    PaperConference(id: 'ACL', displayName: 'ACL'),
    PaperConference(id: 'AAAI', displayName: 'AAAI'),
    PaperConference(id: 'EMNLP', displayName: 'EMNLP'),
    PaperConference(id: 'ECCV', displayName: 'ECCV'),
    PaperConference(id: 'ICCV', displayName: 'ICCV'),
    PaperConference(id: 'ICASSP', displayName: 'ICASSP'),
    PaperConference(id: 'NAACL', displayName: 'NAACL'),
    PaperConference(id: 'IJCAI', displayName: 'IJCAI'),
    PaperConference(id: 'Interspeech', displayName: 'Interspeech'),
    PaperConference(id: 'WACV', displayName: 'WACV'),
    PaperConference(id: 'KDD', displayName: 'KDD'),
    PaperConference(id: 'COLING', displayName: 'COLING'),
    PaperConference(id: 'SIGIR', displayName: 'SIGIR'),
    PaperConference(id: 'CoRL', displayName: 'CoRL'),
    PaperConference(id: 'MLSys', displayName: 'MLSys'),
  ];
}
