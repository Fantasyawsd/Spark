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

  /// 按亮度取色：色相族对齐 Apple 系统色；green/orange/azure 采用
  /// 加深可用变体保证小字号下对白 ≥ 3:1，暗色变体保证在
  /// 暗色卡片（#1C1C1E）上的对比度 ≥ 4.5:1。
  Color colorFor(Brightness brightness) => switch (this) {
        PaperAccent.blue => brightness == Brightness.dark
            ? const Color(0xFF0A84FF)
            : const Color(0xFF007AFF),
        PaperAccent.purple => brightness == Brightness.dark
            ? const Color(0xFFBF5AF2)
            : const Color(0xFFAF52DE),
        PaperAccent.green => brightness == Brightness.dark
            ? const Color(0xFF30D158)
            : const Color(0xFF248A3D),
        PaperAccent.pink => brightness == Brightness.dark
            ? const Color(0xFFFF375F)
            : const Color(0xFFFF2D55),
        PaperAccent.azure => brightness == Brightness.dark
            ? const Color(0xFF64D2FF)
            : const Color(0xFF0088B0),
        PaperAccent.orange => brightness == Brightness.dark
            ? const Color(0xFFFF9F0A)
            : const Color(0xFFC93400),
      };
}
