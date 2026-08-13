import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spark/src/features/papers/data/paper_pdf_downloader.dart';
import 'package:spark/src/features/papers/domain/paper_pdf.dart';

void main() {
  test('downloads a valid PDF body', () async {
    final downloader = PaperPdfDownloader(
      client: _ResponseClient(
        chunks: const [
          [0x25, 0x50, 0x44, 0x46, 0x2d, 1, 2],
        ],
      ),
    );

    final bytes = await downloader.download(
      Uri.parse('https://example.test/paper.pdf'),
    );

    expect(bytes.take(4).toList(), [0x25, 0x50, 0x44, 0x46]);
  });

  test('rejects a non-PDF response', () async {
    final downloader = PaperPdfDownloader(
      client: _ResponseClient(
        chunks: const [
          [0x3c, 0x68, 0x74, 0x6d, 0x6c],
        ],
      ),
    );

    await expectLater(
      downloader.download(Uri.parse('https://example.test/paper.pdf')),
      throwsA(
        isA<PaperPdfException>().having(
          (error) => error.message,
          'message',
          '下载的内容不是有效的 PDF。',
        ),
      ),
    );
  });

  test('cancels a streamed response after crossing the byte limit', () async {
    final client = _ResponseClient(
      chunks: const [
        [0x25, 0x50, 0x44, 0x46, 0x2d],
        [1, 2, 3, 4, 5, 6],
      ],
    );
    final downloader = PaperPdfDownloader(client: client, maxDownloadBytes: 10);

    await expectLater(
      downloader.download(Uri.parse('https://example.test/paper.pdf')),
      throwsA(isA<PaperPdfException>()),
    );

    expect(client.streamCancelled, isTrue);
  });
}

class _ResponseClient extends http.BaseClient {
  _ResponseClient({required this.chunks});

  final List<List<int>> chunks;
  bool streamCancelled = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    late StreamController<List<int>> controller;
    controller = StreamController<List<int>>(
      onListen: () async {
        for (final chunk in chunks) {
          controller.add(chunk);
          await Future<void>.delayed(Duration.zero);
        }
        await controller.close();
      },
      onCancel: () {
        streamCancelled = true;
      },
    );
    return http.StreamedResponse(controller.stream, 200);
  }
}
