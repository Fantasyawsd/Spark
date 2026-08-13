import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/navigation/spark_route_observer.dart';
import '../core/theme/spark_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/theme/theme_preference_repository.dart';
import 'spark_bootstrap.dart';
import 'spark_dependencies.dart';
import 'spark_shell.dart';

export 'spark_shell.dart' show SparkShell;

class SparkApp extends StatefulWidget {
  const SparkApp({
    super.key,
    this.config = const AppConfig.production(),
    this.showSplash = true,
    this.dependencies,
  });

  final AppConfig config;
  final bool showSplash;
  final SparkDependencies? dependencies;

  @override
  State<SparkApp> createState() => _SparkAppState();
}

class _SparkAppState extends State<SparkApp> {
  late final SparkDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ?? SparkDependencies.preview();
    unawaited(
      ThemeController.instance.configure(
        _dependencies.themePreferenceRepository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: widget.config.applicationTitle,
        debugShowCheckedModeBanner: widget.config.showDebugBanner,
        theme: SparkTheme.light(),
        darkTheme: SparkTheme.dark(),
        themeMode: switch (ThemeController.instance.mode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        navigatorObservers: [SparkRouteObserver.instance],
        home: SparkBootstrap(
          showSplash: widget.showSplash,
          child: SparkShell(
            dependencies: _dependencies,
            features: widget.config.features,
          ),
        ),
      ),
    );
  }
}
