import 'package:flutter/material.dart';
import 'package:paperflow/paperflow.dart';

void main() {
  final config = AppConfig.fromEnvironment();
  runApp(
    PaperFlowApp(
      config: config,
      dependencies: PaperFlowDependencies.production(),
    ),
  );
}
