import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../domain/chat_ai_service.dart';
import '../paper_ai_ui_tokens.dart';
import 'paper_ai_model_avatar.dart';

const paperAiReasoningOptions = [
  ChatReasoningEffort.none,
  ChatReasoningEffort.medium,
  ChatReasoningEffort.high,
  ChatReasoningEffort.max,
];

Future<void> showPaperAiModelSheet(
  BuildContext context, {
  required String modelName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: PaperAiUiTokens.canvas(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SparkDesignTokens.radius3Xl),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
        child: Container(
          key: const ValueKey('paper-ai-model-option'),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PaperAiUiTokens.assistantReasoning(context),
            borderRadius: BorderRadius.circular(SparkDesignTokens.radius2Xl),
          ),
          child: Row(
            children: [
              const PaperAiModelAvatar(size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  modelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: SparkFontSizes.bodyLarge,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: PaperAiUiTokens.accent(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showPaperAiReasoningSheet(
  BuildContext context, {
  required ChatReasoningEffort initialEffort,
  required ValueChanged<ChatReasoningEffort> onChanged,
}) async {
  var selected = paperAiReasoningOptions.contains(initialEffort)
      ? initialEffort
      : ChatReasoningEffort.medium;
  if (selected != initialEffort) onChanged(selected);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: PaperAiUiTokens.canvas(context),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => _ReasoningSheet(
        selected: selected,
        onSelected: (effort) {
          setSheetState(() => selected = effort);
          onChanged(effort);
        },
      ),
    ),
  );
}

class _ReasoningSheet extends StatelessWidget {
  const _ReasoningSheet({required this.selected, required this.onSelected});

  final ChatReasoningEffort selected;
  final ValueChanged<ChatReasoningEffort> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = paperAiReasoningOptions
        .indexOf(selected)
        .clamp(0, paperAiReasoningOptions.length - 1);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '模型思考强度',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: SparkFontSizes.headline,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Icon(
              Icons.lightbulb_outline_rounded,
              color: PaperAiUiTokens.accent(context),
              size: 42,
            ),
            const SizedBox(height: 6),
            Text(
              paperAiReasoningLabel(selected),
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: SparkFontSizes.title,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 18,
                  trackShape: const PaperAiReasoningSliderTrackShape(),
                  activeTrackColor: PaperAiUiTokens.accent(context),
                  inactiveTrackColor: Color.alphaBlend(
                    scheme.onSurface.withValues(alpha: 0.08),
                    scheme.surface,
                  ),
                  thumbColor: scheme.surface,
                  disabledThumbColor: scheme.surface,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 22,
                    elevation: 2,
                    pressedElevation: 4,
                  ),
                  overlayColor: PaperAiUiTokens.accent(
                    context,
                  ).withValues(alpha: 0.08),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 27,
                  ),
                  tickMarkShape: SliderTickMarkShape.noTickMark,
                ),
                child: Slider(
                  key: const ValueKey('paper-ai-reasoning-slider'),
                  value: selectedIndex.toDouble(),
                  min: 0,
                  max: (paperAiReasoningOptions.length - 1).toDouble(),
                  divisions: paperAiReasoningOptions.length - 1,
                  onChanged: (value) =>
                      onSelected(paperAiReasoningOptions[value.round()]),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final effort in paperAiReasoningOptions)
                  Expanded(
                    child: GestureDetector(
                      key: ValueKey(
                        'paper-ai-reasoning-option-${effort.apiValue}',
                      ),
                      onTap: () => onSelected(effort),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          paperAiReasoningLabel(effort),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: effort == selected
                                ? PaperAiUiTokens.accent(context)
                                : scheme.onSurfaceVariant,
                            fontSize: SparkFontSizes.footnote,
                            fontWeight: effort == selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String paperAiReasoningLabel(ChatReasoningEffort effort) {
  return switch (effort) {
    ChatReasoningEffort.none => '关闭',
    ChatReasoningEffort.low || ChatReasoningEffort.medium => '自动',
    ChatReasoningEffort.high => '高',
    ChatReasoningEffort.max => '极致',
  };
}

class PaperAiReasoningSliderTrackShape extends RoundedRectSliderTrackShape {
  const PaperAiReasoningSliderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: 0,
    );
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final dotRadius = trackRect.height * 0.16;
    context.canvas
      ..drawCircle(
        Offset(trackRect.left + trackRect.height / 2, trackRect.center.dy),
        dotRadius,
        Paint()..color = sliderTheme.activeTrackColor!.withValues(alpha: 0.45),
      )
      ..drawCircle(
        Offset(trackRect.right - trackRect.height / 2, trackRect.center.dy),
        dotRadius,
        Paint()
          ..color = sliderTheme.inactiveTrackColor!.withValues(alpha: 0.75),
      );
  }
}
