import 'package:flutter/material.dart';

import 'cherry_motion.dart';

class SparkEntryAnimation extends StatelessWidget {
  const SparkEntryAnimation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CherryEntryAnimation(child: child);
  }
}
