import 'package:flutter/material.dart';

import '../../../core/theme/paperflow_theme.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../domain/message_item.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final direct = _tabIndex == 0;
    return ColoredBox(
      color: PaperFlowColors.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _SegmentedTabs(
                  labels: const ['私信', '通知'],
                  selectedIndex: _tabIndex,
                  onSelected: (index) => setState(() => _tabIndex = index),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: PaperFlowColors.primary),
                    ),
                    child: Row(
                      children: [
                        Text('Unread',
                            style: TextStyle(
                                color: PaperFlowColors.primary, fontSize: 12)),
                        const SizedBox(width: 7),
                        CircleAvatar(
                            radius: 4,
                            backgroundColor: PaperFlowColors.primary),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Text('Recent',
                      style: TextStyle(
                          color: PaperFlowColors.muted, fontSize: 13)),
                  const SizedBox(width: 5),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: PaperFlowColors.muted, size: 22),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 92),
                itemCount: demoMessages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _MessageCard(
                  item: demoMessages[index],
                  showAvatar: direct,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs(
      {required this.labels,
      required this.selectedIndex,
      required this.onSelected});

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 47,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? PaperFlowColors.primarySoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Center(
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: selected
                          ? PaperFlowColors.primary
                          : PaperFlowColors.muted,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.item, required this.showAvatar});

  final MessageItem item;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final direct = item.kind == MessageKind.direct;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      radius: 19,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MessageIcon(item: item, showAvatar: showAvatar),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PaperFlowColors.ink,
                    fontSize: direct ? 16 : 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PaperFlowColors.muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.time,
                  style: const TextStyle(
                      color: PaperFlowColors.muted, fontSize: 11)),
              const SizedBox(height: 13),
              if (item.unread > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 23),
                  height: 23,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: PaperFlowColors.primary,
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                  ),
                  child: Center(
                    child: Text(
                      '${item.unread}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageIcon extends StatelessWidget {
  const _MessageIcon({required this.item, required this.showAvatar});

  final MessageItem item;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    if (showAvatar && item.avatarUrl != null) {
      return ProfileAvatar(
          imageUrl: item.avatarUrl!, radius: 31, showStatus: item.unread > 0);
    }

    final data = switch (item.kind) {
      MessageKind.liked => (
          Icons.favorite_rounded,
          const Color(0xFFFFE4EA),
          PaperFlowColors.primary
        ),
      MessageKind.commented => (
          Icons.chat_bubble_rounded,
          const Color(0xFFECE9FF),
          PaperFlowColors.purple
        ),
      MessageKind.system => (
          Icons.notifications_rounded,
          const Color(0xFFE3F0FF),
          PaperFlowColors.blue
        ),
      MessageKind.direct => (
          Icons.chat_bubble_rounded,
          PaperFlowColors.primarySoft,
          PaperFlowColors.primary
        ),
    };

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(color: data.$2, shape: BoxShape.circle),
      child: Icon(data.$1, color: data.$3, size: 29),
    );
  }
}
