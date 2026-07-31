import 'package:flutter/material.dart';

import '../theme/paperflow_theme.dart';

class PaperFlowTabBar extends StatelessWidget {
  const PaperFlowTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.pageController,
    this.height = 38,
    this.indicatorWidth = 38,
    this.textSize = 12,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final PageController? pageController;
  final double height;
  final double indicatorWidth;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    final Listenable animation =
        pageController ?? const AlwaysStoppedAnimation<double>(0);
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final page = pageController?.hasClients == true
                  ? (pageController!.page ?? selectedIndex.toDouble())
                  : selectedIndex.toDouble();
              final clampedPage = page.clamp(0.0, tabs.length - 1.0);
              final cellWidth = constraints.maxWidth / tabs.length;
              final left =
                  cellWidth * clampedPage + (cellWidth - indicatorWidth) / 2;
              return Stack(
                children: [
                  Row(
                    children: [
                      for (var index = 0; index < tabs.length; index++)
                        Expanded(
                          child: InkWell(
                            onTap: () => onSelected(index),
                            splashFactory: NoSplash.splashFactory,
                            overlayColor:
                                WidgetStateProperty.all(Colors.transparent),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                tabs[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: index == selectedIndex
                                      ? PaperFlowColors.primary
                                      : PaperFlowColors.muted,
                                  fontSize: textSize,
                                  fontWeight: index == selectedIndex
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    left: left,
                    bottom: 0,
                    width: indicatorWidth,
                    height: 2.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: PaperFlowColors.primary,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
