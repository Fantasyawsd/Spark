import 'package:flutter/material.dart';

import '../../../core/theme/paperflow_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/paperflow_sheet.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/surface_card.dart';
import '../../../core/widgets/topic_chip.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PaperFlowColors.canvas,
      child: SafeArea(
        bottom: false,
        child: ListView(
          key: const ValueKey('profile-scroll'),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 94),
          children: const [
            _ProfileToolbar(),
            SizedBox(height: 14),
            _ProfileIdentity(),
            SizedBox(height: 18),
            _ProfileStats(),
            SizedBox(height: 18),
            _FavoritesCard(),
            SizedBox(height: 14),
            _ReadingHistoryCard(),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _InterestsCard()),
                SizedBox(width: 10),
                Expanded(child: _PostsCard()),
              ],
            ),
            SizedBox(height: 14),
            _QuickActionsCard(),
          ],
        ),
      ),
    );
  }
}

class _ProfileToolbar extends StatelessWidget {
  const _ProfileToolbar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const _ToolbarIcon(icon: Icons.notifications_none_rounded, badge: 2),
        const SizedBox(width: 12),
        _ToolbarIcon(
          icon: Icons.settings_outlined,
          onTap: () => showPaperThemeSheet(context),
        ),
      ],
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({required this.icon, this.badge = 0, this.onTap});

  final IconData icon;
  final int badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, color: PaperFlowColors.ink, size: 27)),
            if (badge > 0)
              Positioned(
                right: -1,
                top: -3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                      color: PaperFlowColors.primary, shape: BoxShape.circle),
                  child: Center(
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const ProfileAvatar(
              imageUrl: 'https://i.pravatar.cc/300?img=47',
              radius: 54,
            ),
            Positioned(
              right: 1,
              bottom: 3,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: PaperFlowColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 17),
              ),
            ),
          ],
        ),
        const SizedBox(width: 17),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Alex Chen',
                    style: TextStyle(
                      color: PaperFlowColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  _VipBadge(),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'PhD Student @ Tsinghua University',
                style: TextStyle(color: PaperFlowColors.muted, fontSize: 13),
              ),
              SizedBox(height: 7),
              Text(
                'Exploring the intelligence of models and the boundaries of reasoning.',
                style: TextStyle(
                    color: PaperFlowColors.muted, fontSize: 12, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: PaperFlowColors.primarySoft,
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: PaperFlowColors.primary.withValues(alpha: 0.55)),
      ),
      child: Text(
        '◇ VIP',
        style: TextStyle(
            color: PaperFlowColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _ProfileStat(value: '128', label: 'Following'),
        _StatDivider(),
        _ProfileStat(value: '1.2k', label: 'Followers'),
        _StatDivider(),
        _ProfileStat(value: '342', label: 'Saved Papers'),
        _StatDivider(),
        _ProfileStat(value: '56', label: 'Posts'),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              style: const TextStyle(
                  color: PaperFlowColors.muted, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
        height: 37,
        child: VerticalDivider(width: 1, color: PaperFlowColors.line));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.icon, required this.title, this.action = '查看全部'});

  final IconData icon;
  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: PaperFlowColors.muted, size: 21),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ),
        Text(action,
            style:
                const TextStyle(color: PaperFlowColors.muted, fontSize: 11.5)),
        const Icon(Icons.chevron_right_rounded,
            color: PaperFlowColors.muted, size: 19),
      ],
    );
  }
}

class _FavoritesCard extends StatelessWidget {
  const _FavoritesCard();

  static List<(String, String, IconData, Color)> get items => [
    ('NLP', '156', Icons.chat_bubble_rounded, PaperFlowColors.primary),
    ('CV', '98', Icons.photo_camera_rounded, PaperFlowColors.blue),
    ('RL', '64', Icons.query_stats_rounded, PaperFlowColors.purple),
    ('LLM', '112', Icons.psychology_rounded, PaperFlowColors.green),
    ('Agents', '47', Icons.smart_toy_rounded, PaperFlowColors.orange),
  ];

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _SectionHeader(icon: Icons.bookmark_rounded, title: '我的收藏'),
          const SizedBox(height: 14),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  width: 92,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: PaperFlowColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(item.$3, color: item.$4, size: 20),
                          const SizedBox(width: 7),
                          Text(item.$1,
                              style: const TextStyle(
                                  color: PaperFlowColors.ink,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const Spacer(),
                      Text(item.$2,
                          style: const TextStyle(
                              color: PaperFlowColors.muted, fontSize: 11)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingHistoryCard extends StatelessWidget {
  const _ReadingHistoryCard();

  @override
  Widget build(BuildContext context) {
    const heights = [36.0, 52.0, 68.0, 38.0, 41.0, 22.0, 25.0];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _SectionHeader(icon: Icons.schedule_rounded, title: '阅读历史'),
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(
                width: 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('23',
                        style: TextStyle(
                            color: PaperFlowColors.ink,
                            fontSize: 27,
                            fontWeight: FontWeight.w800)),
                    Text('papers',
                        style: TextStyle(
                            color: PaperFlowColors.muted, fontSize: 11)),
                    SizedBox(height: 10),
                    Text('本周阅读',
                        style: TextStyle(
                            color: PaperFlowColors.muted, fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 104,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(heights.length, (index) {
                      final active = index < 3;
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 10,
                              height: heights[index],
                              decoration: BoxDecoration(
                                color: active
                                    ? PaperFlowColors.primary
                                        .withValues(alpha: 0.82)
                                    : PaperFlowColors.line,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(days[index],
                                style: TextStyle(
                                    color: index == 2
                                        ? PaperFlowColors.primary
                                        : PaperFlowColors.muted,
                                    fontSize: 9.5)),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: CircularProgressIndicator(
                            value: 0.68,
                            strokeWidth: 6,
                            backgroundColor: PaperFlowColors.primarySoft,
                            color: PaperFlowColors.primary,
                          ),
                        ),
                        const Text('68%',
                            style: TextStyle(
                                color: PaperFlowColors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Text('周阅读目标',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: PaperFlowColors.muted, fontSize: 9.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InterestsCard extends StatelessWidget {
  const _InterestsCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
              icon: Icons.explore_rounded, title: '兴趣方向', action: '编辑'),
          SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              TopicChip(label: 'NLP', compact: true, selected: true),
              TopicChip(label: 'LLM', compact: true, selected: true),
              TopicChip(label: 'Agents', compact: true, selected: true),
              TopicChip(
                  label: 'RL',
                  compact: true,
                  selected: true,
                  color: PaperFlowColors.blue),
              TopicChip(
                  label: 'Alignment',
                  compact: true,
                  selected: true,
                  color: PaperFlowColors.purple),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostsCard extends StatelessWidget {
  const _PostsCard();

  @override
  Widget build(BuildContext context) {
    return const SurfaceCard(
      padding: EdgeInsets.all(14),
      child: Column(
        children: [
          _SectionHeader(icon: Icons.edit_square, title: '我的帖子'),
          SizedBox(height: 12),
          _PostMetric(icon: Icons.edit_note_rounded, label: '发布', value: '56'),
          _PostMetric(
              icon: Icons.thumb_up_alt_rounded, label: '获得点赞', value: '1.2k'),
          _PostMetric(
              icon: Icons.favorite_border_rounded, label: '收藏', value: '342'),
          _PostMetric(
              icon: Icons.chat_bubble_rounded, label: '评论', value: '198'),
        ],
      ),
    );
  }
}

class _PostMetric extends StatelessWidget {
  const _PostMetric(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: PaperFlowColors.muted, size: 15),
          const SizedBox(width: 7),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: PaperFlowColors.muted, fontSize: 10.5))),
          Text(value,
              style: const TextStyle(
                  color: PaperFlowColors.muted, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  static const items = [
    (Icons.drafts_outlined, '草稿箱', '3'),
    (Icons.note_alt_outlined, '我的笔记', '128'),
    (Icons.download_rounded, '下载管理', '24'),
    (Icons.language_rounded, '语言 / 偏好', '简体中文'),
    (Icons.dark_mode_outlined, '夜间模式', '跟随系统'),
  ];

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('快捷入口',
              style: TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(items.length, (index) {
              final item = items[index];
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: index == items.length - 1
                        ? null
                        : const Border(
                            right: BorderSide(color: PaperFlowColors.line)),
                  ),
                  child: Column(
                    children: [
                      Icon(item.$1, color: PaperFlowColors.muted, size: 22),
                      const SizedBox(height: 7),
                      Text(item.$2,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: PaperFlowColors.ink, fontSize: 9.5)),
                      const SizedBox(height: 3),
                      Text(item.$3,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: PaperFlowColors.muted, fontSize: 8.5)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// 打开设置底部面板，目前提供主题色切换。
void showPaperThemeSheet(BuildContext context) {
  showPaperFlowSheet<void>(
    context: context,
    builder: (context) => Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: PaperFlowColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '设置',
              style: TextStyle(
                color: PaperFlowColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '主题色',
              style: TextStyle(
                color: PaperFlowColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: ThemeController.instance,
              builder: (context, _) {
                final current = ThemeController.instance.color;
                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: PaperThemeColor.values.map((c) {
                    final selected = c == current;
                    return GestureDetector(
                      onTap: () => ThemeController.instance.setColor(c),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c.value,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? PaperFlowColors.ink
                                    : PaperFlowColors.line,
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A15213A),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: selected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            c.label,
                            style: TextStyle(
                              color: selected
                                  ? PaperFlowColors.ink
                                  : PaperFlowColors.muted,
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
