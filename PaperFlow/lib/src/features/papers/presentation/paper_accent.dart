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
        _ => _accentForTopic(topics),
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
        PaperAccent.blue => const Color(0xFF4A7FCA),
        PaperAccent.purple => const Color(0xFF7758C9),
        PaperAccent.green => const Color(0xFF38A984),
        PaperAccent.pink => const Color(0xFFEF5B7E),
        PaperAccent.azure => const Color(0xFF2B82F6),
        PaperAccent.orange => const Color(0xFFFF8A21),
      };
}
