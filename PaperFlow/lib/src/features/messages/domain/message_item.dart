import 'package:flutter/material.dart';

enum MessageKind { direct, liked, commented, system }

@immutable
class MessageItem {
  const MessageItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.kind,
    this.avatarUrl,
    this.unread = 0,
  });

  final String title;
  final String subtitle;
  final String time;
  final MessageKind kind;
  final String? avatarUrl;
  final int unread;
}

const demoMessages = <MessageItem>[
  MessageItem(
    title: 'Yelong Shen',
    subtitle:
        'Hi! I’m interested in your LoRA fine-tuning setup. Could you share the training config?',
    time: '09:28',
    kind: MessageKind.direct,
    avatarUrl: 'https://i.pravatar.cc/240?img=12',
    unread: 2,
  ),
  MessageItem(
    title: 'Zeyuan Allen-Zhu',
    subtitle:
        'Thanks for sharing your paper. I have a question about the rank allocation.',
    time: 'Yesterday',
    kind: MessageKind.direct,
    avatarUrl: 'https://i.pravatar.cc/240?img=47',
    unread: 1,
  ),
  MessageItem(
    title: 'Phillip Wallis',
    subtitle:
        'Great work! Have you tried evaluating on multilingual benchmarks?',
    time: 'Yesterday',
    kind: MessageKind.direct,
    avatarUrl: 'https://i.pravatar.cc/240?img=14',
  ),
  MessageItem(
    title: 'Alden liked your paper',
    subtitle: 'LoRA: Low-Rank Adaptation of Large Language Models',
    time: '2d',
    kind: MessageKind.liked,
  ),
  MessageItem(
    title: 'Beatrice commented on your paper',
    subtitle: '“Very insightful ablation study on rank selection!”',
    time: '2d',
    kind: MessageKind.commented,
  ),
  MessageItem(
    title: 'ICLR 2024 Updates',
    subtitle: 'Your paper submission has been assigned to Area Chair.',
    time: '3d',
    kind: MessageKind.system,
  ),
];
