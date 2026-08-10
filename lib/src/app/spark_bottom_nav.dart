import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/motion/motion_tokens.dart';
import '../core/theme/spark_design_tokens.dart';
import '../core/theme/spark_font_sizes.dart';
import '../core/theme/spark_theme.dart';

class SparkBottomNav extends StatelessWidget {
  const SparkBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.showCommunity = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool showCommunity;

  @override
  Widget build(BuildContext context) {
    final items = <_NavigationItem>[
      const _NavigationItem(
        label: '论文',
        icon: Icons.description_outlined,
        selectedIcon: Icons.description_rounded,
      ),
      const _NavigationItem(
        label: 'ChatPaper',
        icon: Icons.chat_bubble_outline_rounded,
        selectedIcon: Icons.chat_bubble_rounded,
      ),
      if (showCommunity)
        const _NavigationItem(
          label: '社区',
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
        ),
      const _NavigationItem(
        label: '我的',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SparkDesignTokens.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: SparkColors.of(context).popover.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(SparkDesignTokens.radiusXl),
              border: Border.all(color: SparkColors.of(context).line),
              boxShadow: SparkDesignTokens.floatingShadow,
            ),
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: SizedBox(
                height: 50,
                child: Row(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      _NavItem(
                        item: items[index],
                        index: index,
                        selectedIndex: selectedIndex,
                        onSelected: onSelected,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.index,
    required this.selectedIndex,
    required this.onSelected,
  });

  final _NavigationItem item;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final color =
        selected ? SparkColors.of(context).ink : SparkColors.of(context).muted;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
          child: InkWell(
            key: ValueKey('bottom-nav-$index'),
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
            child: AnimatedContainer(
              duration: MotionTokens.duration(
                context,
                MotionTokens.tabDuration,
              ),
              curve: MotionTokens.enterCurve,
              decoration: BoxDecoration(
                color: selected
                    ? SparkColors.of(context).accent
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    height: 25,
                    child: Align(
                      child: Icon(
                        selected ? item.selectedIcon : item.icon,
                        size: 22,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: SparkFontSizes.tiny,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
