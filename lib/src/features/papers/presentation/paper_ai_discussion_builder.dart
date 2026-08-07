import 'package:flutter/widgets.dart';

import '../domain/paper.dart';

typedef PaperAiDiscussionBuilder = Widget Function(
  BuildContext context, {
  required Paper paper,
  required List<String> generatedKeywords,
  required ScrollController? scrollController,
});
