import 'package:flutter/material.dart';

import '../motion/motion_tokens.dart';
import '../theme/paperflow_theme.dart';

/// Flat content tabs for dense reading surfaces.
///
/// The control follows the common mobile reading pattern used by document and
/// productivity products: text labels, one neutral baseline and a short dark
/// indicator. There are no selected shadows or elevated capsules.
class PaperFlowSegmentedControl extends StatelessWidget {
  const PaperFlowSegmentedControl({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 38,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: PaperFlowColors.line)),
        ),
        child: SizedBox(
          height: height,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < tabs.length; index++)
                  _ContentTab(
                    label: tabs[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentTab extends StatelessWidget {
  const _ContentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        child: AnimatedContainer(
          duration: MotionTokens.duration(context, MotionTokens.tabDuration),
          curve: MotionTokens.enterCurve,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? PaperFlowColors.ink : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? PaperFlowColors.ink : PaperFlowColors.muted,
              fontSize: 13,
              fontFamily: PaperFlowTheme.platformCjkFontFamily(),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
