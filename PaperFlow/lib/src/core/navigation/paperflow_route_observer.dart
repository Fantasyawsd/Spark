import 'package:flutter/material.dart';

/// Shared route visibility signal for screens that own foreground-only work.
class PaperFlowRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  PaperFlowRouteObserver._();

  static final PaperFlowRouteObserver instance = PaperFlowRouteObserver._();
}
