import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/paperflow_theme.dart';

class PaperFlowBottomNav extends StatelessWidget {
  const PaperFlowBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.papersGridMode = false,
    this.messageCount = 2,
    this.onCreate,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool papersGridMode;
  final int messageCount;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PaperFlowColors.line),
            ),
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: SizedBox(
                height: 52,
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
                      label: '社区',
                      icon: Icons.groups_outlined,
                      selectedIcon: Icons.groups_rounded,
                      index: 1,
                      selectedIndex: selectedIndex,
                      onSelected: onSelected,
                    ),
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          key: const ValueKey('create-button'),
                          onTap: onCreate,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: PaperFlowColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x52FF315F),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _NavItem(
                      label: '聊天',
                      icon: Icons.chat_bubble_outline_rounded,
                      selectedIcon: Icons.chat_bubble_rounded,
                      index: 2,
                      selectedIndex: selectedIndex,
                      showUnreadDot: messageCount > 0,
                      onSelected: onSelected,
                    ),
                    _NavItem(
                      label: '我的',
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      index: 3,
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
    this.showUnreadDot = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool showUnreadDot;

  @override
  Widget build(BuildContext context) {
    final selected = index == selectedIndex;
    final color = selected ? PaperFlowColors.ink : PaperFlowColors.muted;
    return Expanded(
      child: InkResponse(
        onTap: () => onSelected(index),
        radius: 34,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 27,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Icon(
                      selected ? selectedIcon : icon,
                      size: 25,
                      color: color,
                    ),
                  ),
                  if (showUnreadDot)
                    Positioned(
                      right: 1,
                      top: 0,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: PaperFlowColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
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
    );
  }
}
