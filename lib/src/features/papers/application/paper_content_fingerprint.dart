import 'dart:convert';

import '../domain/paper.dart';

String paperContentFingerprint(Paper paper, {required String namespace}) {
  final bytes = utf8.encode(
    '${paper.title.trim()}$namespace'
    '${paper.content.originalAbstractMarkdown.trim()}',
  );
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
