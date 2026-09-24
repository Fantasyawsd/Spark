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
    final palette = SparkColors.of(context);
    final items = <_NavigationItem>[
      const _NavigationItem(
        label: '论文',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
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
        icon: Icons.bookmarks_outlined,
        selectedIcon: Icons.bookmarks_rounded,
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
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
    final palette = SparkColors.of(context);
    final selected = index == selectedIndex;
    final color = selected ? palette.primary : palette.muted;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusMd),
          child: Semantics(
            selected: selected,
            button: true,
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
                      ? palette.primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(SparkDesignTokens.radiusMd),
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
                        fontSize: SparkFontSizes.footnote,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
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
