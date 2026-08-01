import 'package:flutter/material.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  runApp(
    PaperFlowApp(
      dependencies: PaperFlowDependencies.production(),
    ),
  );
}
