import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/cherry_primitives.dart';

class PapersHeader extends StatelessWidget {
  const PapersHeader({
    super.key,
    required this.primaryIndex,
    required this.selectedTopic,
    required this.onPrimarySelected,
    required this.onTopicFilter,
    required this.onSearch,
  });

  static const primaryCategories = ['推荐', '关注', '最新'];
  static const height = 52.0;

  final int primaryIndex;
  final String selectedTopic;
  final ValueChanged<int> onPrimarySelected;
  final VoidCallback onTopicFilter;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final showTopicFilter = primaryIndex == 0;
    return Material(
      color: PaperFlowColors.card,
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
                child: _PrimaryNavigation(
                  categories: primaryCategories,
                  selectedIndex: primaryIndex,
                  onSelected: onPrimarySelected,
                ),
              ),
              if (showTopicFilter)
                _TopicFilterButton(
                  topic: selectedTopic,
                  onPressed: onTopicFilter,
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

class _PrimaryNavigation extends StatelessWidget {
  const _PrimaryNavigation({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < categories.length; index++)
          Padding(
            padding: EdgeInsets.only(
              right: index == categories.length - 1 ? 0 : 22,
            ),
            child: _PrimaryTab(
              key: ValueKey('paper-primary-category-$index'),
              label: categories[index],
              selected: selectedIndex == index,
              onTap: () => onSelected(index),
            ),
          ),
      ],
    );
  }
}

class _PrimaryTab extends StatelessWidget {
  const _PrimaryTab({
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
                color: selected ? PaperFlowColors.ink : PaperFlowColors.muted,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                fontFamily: PaperFlowTheme.platformCjkFontFamily(),
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
                color: PaperFlowColors.primary,
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

class _TopicFilterButton extends StatelessWidget {
  const _TopicFilterButton({required this.topic, required this.onPressed});

  final String topic;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final filtered = topic != '全部';
    return CherryIconButton(
      key: const ValueKey('paper-topic-filter'),
      tooltip: filtered ? '研究领域：$topic' : '筛选研究领域',
      onPressed: onPressed,
      icon: Icons.tune_rounded,
      iconSize: 19,
      size: 36,
      selected: filtered,
      badge: Badge(
        isLabelVisible: filtered,
        smallSize: 7,
        backgroundColor: PaperFlowColors.primary,
        child: const Icon(
          Icons.tune_rounded,
          size: 19,
          color: PaperFlowColors.ink,
        ),
      ),
    );
  }
}
