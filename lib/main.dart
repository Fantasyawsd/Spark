import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:spark/spark.dart';

void main() {
  final config = AppConfig.fromEnvironment(platformFlavor: appFlavor);
  runApp(
    SparkApp(
      config: config,
      dependencies: SparkDependencies.production(),
    ),
  );
}
