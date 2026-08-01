import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:paperflow/paperflow.dart';

void main() {
  final config = AppConfig.fromEnvironment(platformFlavor: appFlavor);
  runApp(
    PaperFlowApp(
      config: config,
      dependencies: PaperFlowDependencies.production(),
    ),
  );
}
