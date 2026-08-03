import 'package:flutter/material.dart';

import '../domain/paper.dart';

enum PaperAccent { blue, purple, green, pink, azure, orange }

extension PaperAccentForRecord on Paper {
  PaperAccent get accent => switch (id) {
        'lora-2021' => PaperAccent.blue,
        'mamba-2023' => PaperAccent.purple,
        'retrieval-long-context-2025' => PaperAccent.green,
        'qlora-2023' => PaperAccent.pink,
        'segment-anything-2023' => PaperAccent.azure,
        'swe-agent-2024' => PaperAccent.orange,
        _ => _accentForTopic([...contentKeywords, ...subjects]),
      };
}

PaperAccent _accentForTopic(Iterable<String> topics) {
  final joined = topics.join(' ').toLowerCase();
  if (joined.contains('vision') || joined.contains('cv')) {
    return PaperAccent.azure;
  }
  if (joined.contains('language') || joined.contains('llm')) {
    return PaperAccent.purple;
  }
  if (joined.contains('robot')) return PaperAccent.orange;
  if (joined.contains('retrieval')) return PaperAccent.green;
  return PaperAccent.blue;
}

extension PaperAccentColor on PaperAccent {
  Color get color => switch (this) {
        PaperAccent.blue => const Color(0xFF4B74A7),
        PaperAccent.purple => const Color(0xFF735C9E),
        PaperAccent.green => const Color(0xFF3E806F),
        PaperAccent.pink => const Color(0xFFC95A73),
        PaperAccent.azure => const Color(0xFF3F83B5),
        PaperAccent.orange => const Color(0xFFB66A2C),
      };
}
