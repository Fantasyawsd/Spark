import 'package:flutter/material.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/paperflow_sheet.dart';

const availablePaperCategories = [
  'AI Agent',
  '多模态',
  '强化学习',
  '机器人',
  '语音',
  '推荐系统',
  '数据挖掘',
  'AI 安全',
];

Future<String?> showPaperTopicPicker(
  BuildContext context, {
  required Iterable<String> topics,
  required String selectedTopic,
}) {
  final visibleTopics = topics.toSet().toList(growable: false);
  return showPaperFlowSheet<String>(
    context: context,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PaperFlowSheetHandle(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '研究领域',
                      style: TextStyle(
                        color: PaperFlowColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (selectedTopic != '全部')
                    TextButton(
                      onPressed: () => Navigator.pop(context, '全部'),
                      child: const Text('清除筛选'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '选择一个领域，推荐流将只展示相关论文',
                style: TextStyle(
                  color: PaperFlowColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 9,
                children: [
                  for (final topic in visibleTopics)
                    ChoiceChip(
                      key: ValueKey('paper-topic-choice-$topic'),
                      label: Text(topic == '全部' ? '全部领域' : topic),
                      selected: topic == selectedTopic,
                      showCheckmark: false,
                      onSelected: (_) => Navigator.pop(context, topic),
                      selectedColor: PaperFlowColors.primarySoft,
                      backgroundColor: PaperFlowColors.canvas,
                      side: BorderSide(
                        color: topic == selectedTopic
                            ? PaperFlowColors.primary
                            : Colors.transparent,
                      ),
                      labelStyle: TextStyle(
                        color: topic == selectedTopic
                            ? PaperFlowColors.primary
                            : PaperFlowColors.ink,
                        fontSize: 12.5,
                        fontWeight: topic == selectedTopic
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
