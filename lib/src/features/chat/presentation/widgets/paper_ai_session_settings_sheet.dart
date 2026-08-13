import 'package:flutter/material.dart';

import '../../../../core/theme/spark_font_sizes.dart';
import '../../application/chat_skills.dart';
import '../../domain/chat_session_settings.dart';
import '../paper_ai_ui_tokens.dart';

Future<ChatSessionSettings?> showPaperAiSessionSettingsSheet(
  BuildContext context, {
  required ChatSessionSettings initial,
}) {
  return showModalBottomSheet<ChatSessionSettings>(
    context: context,
    backgroundColor: PaperAiUiTokens.canvas(context),
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _PaperAiSessionSettingsSheet(initial: initial),
  );
}

class _PaperAiSessionSettingsSheet extends StatefulWidget {
  const _PaperAiSessionSettingsSheet({required this.initial});

  final ChatSessionSettings initial;

  @override
  State<_PaperAiSessionSettingsSheet> createState() =>
      _PaperAiSessionSettingsSheetState();
}

class _PaperAiSessionSettingsSheetState
    extends State<_PaperAiSessionSettingsSheet> {
  late final TextEditingController _promptController;
  late ChatResponseStyle _responseStyle;
  late final Set<String> _enabledSkills;

  @override
  void initState() {
    super.initState();
    _promptController =
        TextEditingController(text: widget.initial.customSystemPrompt ?? '');
    _responseStyle = widget.initial.responseStyle;
    _enabledSkills = Set<String>.from(widget.initial.enabledSkillIds);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildPromptField(),
              const SizedBox(height: 18),
              _buildResponseStyles(),
              const SizedBox(height: 18),
              _buildSkills(),
              const SizedBox(height: 12),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '会话设置',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: SparkFontSizes.headline,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '设置仅作用于当前会话；留空使用默认提示词。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: SparkFontSizes.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildPromptField() {
    return TextField(
      key: const ValueKey('paper-ai-settings-prompt'),
      controller: _promptController,
      minLines: 3,
      maxLines: 6,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        labelText: '自定义系统提示词',
        hintText: '例如：请始终用中文并给出公式推导。',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildResponseStyles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('回答风格'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final style in ChatResponseStyle.values)
              ChoiceChip(
                key: ValueKey('paper-ai-settings-style-${style.name}'),
                label: Text(style.label),
                selected: _responseStyle == style,
                onSelected: (_) => setState(() => _responseStyle = style),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkills() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('技能'),
        const SizedBox(height: 4),
        for (final skill in ChatSkills.all)
          SwitchListTile(
            key: ValueKey('paper-ai-settings-skill-${skill.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              skill.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: SparkFontSizes.bodyLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: skill.description == null
                ? null
                : Text(
                    skill.description!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: SparkFontSizes.footnote,
                    ),
                  ),
            value: _enabledSkills.contains(skill.id),
            onChanged: (value) => setState(() {
              if (value) {
                _enabledSkills.add(skill.id);
              } else {
                _enabledSkills.remove(skill.id);
              }
            }),
          ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: SparkFontSizes.bodyLarge,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          key: const ValueKey('paper-ai-settings-save'),
          onPressed: () => Navigator.pop(context, _buildSettings()),
          child: const Text('保存'),
        ),
      ],
    );
  }

  ChatSessionSettings _buildSettings() {
    final prompt = _promptController.text.trim();
    return ChatSessionSettings(
      customSystemPrompt: prompt.isEmpty ? null : prompt,
      enabledSkillIds: _enabledSkills.toList(growable: false),
      responseStyle: _responseStyle,
    );
  }
}
