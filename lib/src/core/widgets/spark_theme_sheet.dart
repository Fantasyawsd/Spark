import 'package:flutter/material.dart';

import '../motion/motion_tokens.dart';
import '../theme/spark_design_tokens.dart';
import '../theme/spark_font_sizes.dart';
import '../theme/spark_theme_color.dart';
import '../theme/spark_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/theme_preference_repository.dart';
import 'spark_segmented_control.dart';
import 'spark_sheet.dart';

void showSparkThemeSheet(BuildContext context) {
  showSparkSheet<void>(
    context: context,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: SparkColors.of(context).card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SparkDesignTokens.radius3Xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SparkSheetHandle(height: 20),
              const SizedBox(height: 4),
              Text(
                '主题与配色',
                style: TextStyle(
                  color: SparkColors.of(context).ink,
                  fontSize: SparkFontSizes.titleLarge,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '外观',
                style: TextStyle(
                  color: SparkColors.of(context).muted,
                  fontSize: SparkFontSizes.footnote,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: ThemeController.instance,
                builder: (context, _) => SparkSegmentedControl(
                  tabs: const ['跟随系统', '浅色', '深色'],
                  selectedIndex: ThemeController.instance.mode.index,
                  onSelected: (index) => ThemeController.instance
                      .setMode(AppThemeMode.values[index]),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '强调色',
                style: TextStyle(
                  color: SparkColors.of(context).muted,
                  fontSize: SparkFontSizes.footnote,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              ListenableBuilder(
                listenable: ThemeController.instance,
                builder: (context, _) {
                  final current = ThemeController.instance.color;
                  return Row(
                    children: [
                      for (final color in SparkThemeColor.values)
                        Expanded(
                          child: _ThemeColorOption(
                            color: color,
                            selected: color == current,
                            onTap: () =>
                                ThemeController.instance.setColor(color),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ThemeColorOption extends StatelessWidget {
  const _ThemeColorOption({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final SparkThemeColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: color.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          key: ValueKey('spark-theme-${color.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
          child: AnimatedContainer(
            duration: MotionTokens.duration(context, MotionTokens.tabDuration),
            curve: MotionTokens.pageCurve,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? color.pale : Colors.transparent,
              borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
              border: Border.all(
                color: selected ? color.soft : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.value,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
                const SizedBox(height: 7),
                Text(
                  color.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? SparkColors.of(context).ink
                        : SparkColors.of(context).muted,
                    fontSize: SparkFontSizes.caption,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
