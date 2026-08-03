import 'dart:ui';

import 'package:flutter/material.dart';

import '../motion/motion_tokens.dart';
import '../theme/paperflow_design_tokens.dart';
import '../theme/paperflow_theme.dart';

class PaperFlowBottomNav extends StatelessWidget {
  const PaperFlowBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.papersGridMode = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool papersGridMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            decoration: BoxDecoration(
              color: PaperFlowColors.popover.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(
                PaperFlowDesignTokens.radiusXl,
              ),
              border: Border.all(color: PaperFlowColors.line),
              boxShadow: PaperFlowDesignTokens.floatingShadow,
            ),
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: SizedBox(
                height: 50,
                child: Row(
                  children: [
                    _NavItem(
                      label: papersGridMode ? '‹ 返回' : '论文 ⇄',
                      icon: papersGridMode
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.description_outlined,
                      selectedIcon: papersGridMode
                          ? Icons.arrow_back_ios_new_rounded
                          : Icons.description_rounded,
                      index: 0,
                      selectedIndex: selectedIndex,
                      onSelected: onSelected,
                    ),
                    _NavItem(
                      label: 'ChatPaper',
                      icon: Icons.chat_bubble_outline_rounded,
                      selectedIcon: Icons.chat_bubble_rounded,
                      index: 1,
                      selectedIndex: selectedIndex,
                      onSelected: onSelected,
                    ),
                    _NavItem(
                      label: '我的',
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      index: 2,
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.index,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final color = selected ? PaperFlowColors.ink : PaperFlowColors.muted;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radiusMd),
          child: InkWell(
            key: ValueKey('bottom-nav-$index'),
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(PaperFlowDesignTokens.radiusMd),
            child: AnimatedContainer(
              duration: MotionTokens.duration(
                context,
                MotionTokens.tabDuration,
              ),
              curve: MotionTokens.enterCurve,
              decoration: BoxDecoration(
                color: selected ? PaperFlowColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(
                  PaperFlowDesignTokens.radiusMd,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 32,
                    height: 25,
                    child: Align(
                      alignment: Alignment.center,
                      child: Icon(
                        selected ? selectedIcon : icon,
                        size: 22,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
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
