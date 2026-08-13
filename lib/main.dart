import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:spark/spark.dart';
import 'package:spark/src/core/diagnostics/diagnostics.dart';

void main() {
  SparkDiagnostics.runGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterRuntimeDiagnosticsBinding.install();
    final config = AppConfig.fromEnvironment(platformFlavor: appFlavor);
    runApp(
      SparkApp(
        config: config,
        dependencies: SparkDependencies.forConfig(config),
      ),
    );
  });
}
