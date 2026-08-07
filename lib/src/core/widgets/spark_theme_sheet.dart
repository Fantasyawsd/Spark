import 'package:flutter/material.dart';

import '../motion/motion_tokens.dart';
import '../theme/spark_theme_color.dart';
import '../theme/spark_theme.dart';
import '../theme/theme_controller.dart';
import 'spark_sheet.dart';

void showSparkThemeSheet(BuildContext context) {
  showSparkSheet<void>(
    context: context,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: SparkColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              const Text(
                '主题与配色',
                style: TextStyle(
                  color: SparkColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '强调色',
                style: TextStyle(
                  color: SparkColors.muted,
                  fontSize: 12,
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
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: MotionTokens.duration(
              context,
              MotionTokens.tabDuration,
            ),
            curve: MotionTokens.pageCurve,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? color.pale : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
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
                    color: selected ? SparkColors.ink : SparkColors.muted,
                    fontSize: 10.5,
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
