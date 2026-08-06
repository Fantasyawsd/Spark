import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/cherry_primitives.dart';

class PapersHeader extends StatelessWidget {
  const PapersHeader({
    super.key,
    required this.channels,
    required this.selectedIndex,
    required this.onChannelSelected,
    required this.onManageChannels,
    required this.onSearch,
    required this.timeRangeLabel,
    required this.onSelectTimeRange,
  });

  static const fixedChannelLabels = ['推荐', '关注', '最新'];
  static const height = 52.0;

  final List<String> channels;
  final int selectedIndex;
  final ValueChanged<int> onChannelSelected;
  final VoidCallback onManageChannels;
  final VoidCallback onSearch;
  final String timeRangeLabel;
  final VoidCallback onSelectTimeRange;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SparkColors.card,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 6),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('paper-channel-bar'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < channels.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: index == channels.length - 1 ? 0 : 22,
                          ),
                          child: _ChannelTab(
                            key: ValueKey('paper-channel-$index'),
                            label: channels[index],
                            selected: selectedIndex == index,
                            onTap: () => onChannelSelected(index),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              CherryIconButton(
                key: const ValueKey('paper-time-filter'),
                tooltip: timeRangeLabel,
                onPressed: onSelectTimeRange,
                icon: Icons.calendar_today_rounded,
                iconSize: 18,
                size: 36,
              ),
              CherryIconButton(
                key: const ValueKey('paper-channel-manage'),
                tooltip: '管理频道',
                onPressed: onManageChannels,
                icon: Icons.add_rounded,
                iconSize: 20,
                size: 36,
              ),
              CherryIconButton(
                tooltip: '搜索',
                onPressed: onSearch,
                icon: Icons.search_rounded,
                iconSize: 20,
                size: 36,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelTab extends StatelessWidget {
  const _ChannelTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      child: SizedBox(
        height: PapersHeader.height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? SparkColors.ink : SparkColors.muted,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                fontFamily: SparkTheme.platformCjkFontFamily(),
              ),
            ),
            const SizedBox(height: 7),
            AnimatedContainer(
              duration: MotionTokens.duration(
                context,
                MotionTokens.tabDuration,
              ),
              curve: MotionTokens.enterCurve,
              width: selected ? 24 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: SparkColors.primary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
