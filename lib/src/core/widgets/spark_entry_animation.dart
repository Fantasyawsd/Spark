import 'package:flutter/material.dart';

import 'cherry_motion.dart';

class PaperEntryAnimation extends StatelessWidget {
  const PaperEntryAnimation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CherryEntryAnimation(child: child);
  }
}
