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
  /// 亮色模式取值。
  Color get color => colorFor(Brightness.light);

  /// 按亮度取色：暗色变体整体提亮，
  /// 保证作为小号文字/图标色时在暗色卡片上对比度 ≥ 4.5:1。
  Color colorFor(Brightness brightness) => switch (this) {
        PaperAccent.blue => brightness == Brightness.dark
            ? const Color(0xFF7FA8D9)
            : const Color(0xFF4B74A7),
        PaperAccent.purple => brightness == Brightness.dark
            ? const Color(0xFFA78BCF)
            : const Color(0xFF735C9E),
        PaperAccent.green => brightness == Brightness.dark
            ? const Color(0xFF6FB3A0)
            : const Color(0xFF3E806F),
        PaperAccent.pink => brightness == Brightness.dark
            ? const Color(0xFFE88A9E)
            : const Color(0xFFC95A73),
        PaperAccent.azure => brightness == Brightness.dark
            ? const Color(0xFF79AEDD)
            : const Color(0xFF3F83B5),
        PaperAccent.orange => brightness == Brightness.dark
            ? const Color(0xFFE0A066)
            : const Color(0xFFB66A2C),
      };
}
