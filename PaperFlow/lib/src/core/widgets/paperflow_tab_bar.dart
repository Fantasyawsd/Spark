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
    this.contentWidth = false,
    this.selectedColor,
    this.indicatorColor,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final PageController? pageController;
  final double height;
  final double indicatorWidth;
  final double textSize;
  final bool contentWidth;
  final Color? selectedColor;
  final Color? indicatorColor;

  @override
  Widget build(BuildContext context) {
    final Listenable animation =
        pageController ?? const AlwaysStoppedAnimation<double>(0);
    return Material(
      type: MaterialType.transparency,
      elevation: 0,
      shadowColor: Colors.transparent,
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
              final widths = contentWidth
                  ? _tabWidths(context)
                  : List<double>.filled(
                      tabs.length,
                      constraints.maxWidth / tabs.length,
                    );
              final gap = contentWidth ? 18.0 : 0.0;
              final left = contentWidth
                  ? _contentIndicatorLeft(widths, gap, clampedPage)
                  : widths.first * clampedPage +
                      (widths.first - indicatorWidth) / 2;
              return Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize:
                          contentWidth ? MainAxisSize.min : MainAxisSize.max,
                      children: [
                        for (var index = 0; index < tabs.length; index++) ...[
                          if (contentWidth)
                            SizedBox(
                              width: widths[index],
                              child: _tabButton(index),
                            )
                          else
                            Expanded(child: _tabButton(index)),
                          if (contentWidth && index != tabs.length - 1)
                            SizedBox(width: gap),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    left: left,
                    bottom: 0,
                    width: indicatorWidth,
                    height: 2.5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: indicatorColor ?? PaperFlowColors.primary,
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

  Widget _tabButton(int index) {
    return InkWell(
      onTap: () => onSelected(index),
      splashFactory: NoSplash.splashFactory,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              contentWidth ? 2 : 0, 0, contentWidth ? 2 : 0, 8),
          child: Text(
            tabs[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: index == selectedIndex
                  ? (selectedColor ?? PaperFlowColors.primary)
                  : PaperFlowColors.muted,
              fontSize: textSize,
              fontFamily: PaperFlowTheme.platformCjkFontFamily(),
              fontWeight:
                  index == selectedIndex ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  List<double> _tabWidths(BuildContext context) {
    return tabs.map((tab) {
      final painter = TextPainter(
        text: TextSpan(
          text: tab,
          style: TextStyle(
            fontSize: textSize,
            fontFamily: PaperFlowTheme.platformCjkFontFamily(),
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: Directionality.of(context),
      )..layout();
      return painter.width + 20;
    }).toList();
  }

  double _contentIndicatorLeft(
    List<double> widths,
    double gap,
    double page,
  ) {
    double start = 0;
    for (var index = 0; index < page.floor(); index++) {
      start += widths[index] + gap;
    }
    final index = page.floor().clamp(0, widths.length - 1);
    final fraction = page - page.floor();
    final currentCenter = start + widths[index] / 2;
    final nextIndex = (index + 1).clamp(0, widths.length - 1);
    final nextStart = start + (widths[index] + gap);
    final nextCenter = nextStart + widths[nextIndex] / 2;
    return (currentCenter + (nextCenter - currentCenter) * fraction) -
        indicatorWidth / 2;
  }
}
