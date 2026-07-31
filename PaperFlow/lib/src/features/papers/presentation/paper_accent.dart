import 'package:flutter/material.dart';

import '../domain/paper.dart';

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
