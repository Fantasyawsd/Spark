import 'package:flutter/material.dart';

/// Shared route visibility signal for screens that own foreground-only work.
class SparkRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  SparkRouteObserver._();

  static final SparkRouteObserver instance = SparkRouteObserver._();
}
