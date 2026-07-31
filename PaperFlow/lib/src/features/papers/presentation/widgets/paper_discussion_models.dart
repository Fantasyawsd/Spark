import 'package:flutter/material.dart';

@immutable
class PaperCommentData {
  const PaperCommentData({
    required this.id,
    required this.name,
    required this.initials,
    required this.time,
    required this.location,
    required this.body,
    required this.likes,
    required this.replies,
    required this.color,
    this.parentId,
    this.canDelete = false,
    this.liked = false,
  });

  final String id;
  final String name;
  final String initials;
  final String time;
  final String location;
  final String body;
  final int likes;
  final int replies;
  final Color color;
  final String? parentId;
  final bool canDelete;
  final bool liked;
}

@immutable
class PaperChatMessage {
  const PaperChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}
