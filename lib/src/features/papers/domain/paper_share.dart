class PaperSharePayload {
  const PaperSharePayload({required this.subject, required this.text});

  final String subject;
  final String text;
}

enum PaperShareResult { shared, copied, cancelled }

abstract interface class PaperShareService {
  Future<PaperShareResult> share(PaperSharePayload payload);
}

class PaperShareException implements Exception {
  const PaperShareException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
