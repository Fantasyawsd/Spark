import 'package:flutter/material.dart';

import '../../../core/theme/spark_design_tokens.dart';
import '../../../core/theme/spark_font_sizes.dart';
import '../../../core/theme/spark_theme.dart';
import '../../../core/widgets/spark_sheet.dart';
import '../../../core/widgets/surface_card.dart';
import '../application/deepseek_credential_controller.dart';

class DeepSeekSettingsSection extends StatelessWidget {
  const DeepSeekSettingsSection({super.key, required this.controller});

  final DeepSeekCredentialController controller;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final configured = controller.configured;
          return Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: configured
                      ? SparkColors.of(context).primarySoft
                      : SparkColors.of(context).canvas,
                  borderRadius: BorderRadius.circular(
                    SparkDesignTokens.radiusMd,
                  ),
                ),
                child: Icon(
                  Icons.key_rounded,
                  color: configured
                      ? SparkColors.of(context).primary
                      : SparkColors.of(context).muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DeepSeek API',
                      style: TextStyle(
                        color: SparkColors.of(context).ink,
                        fontSize: SparkFontSizes.bodyLarge,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.loading
                          ? '正在读取配置'
                          : configured
                              ? controller.maskedApiKey ?? '已配置'
                              : '未配置',
                      style: TextStyle(
                        color: SparkColors.of(context).muted,
                        fontSize: SparkFontSizes.footnote,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('profile-deepseek-settings'),
                onPressed: controller.loading
                    ? null
                    : () => _showDeepSeekCredentialSheet(context, controller),
                child: Text(configured ? '管理' : '配置'),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _showDeepSeekCredentialSheet(
  BuildContext context,
  DeepSeekCredentialController controller,
) {
  controller.clearError();
  return showSparkSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DeepSeekCredentialSheet(controller: controller),
  );
}

class _DeepSeekCredentialSheet extends StatefulWidget {
  const _DeepSeekCredentialSheet({required this.controller});

  final DeepSeekCredentialController controller;

  @override
  State<_DeepSeekCredentialSheet> createState() =>
      _DeepSeekCredentialSheetState();
}

class _DeepSeekCredentialSheetState extends State<_DeepSeekCredentialSheet> {
  late final TextEditingController _textController;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Material(
      color: SparkColors.of(context).card,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(SparkDesignTokens.radius3Xl),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SparkSheetHandle(height: 22),
                Text(
                  'DeepSeek API 设置',
                  style: TextStyle(
                    color: SparkColors.of(context).ink,
                    fontSize: SparkFontSizes.titleLarge,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('deepseek-api-key-input'),
                  controller: _textController,
                  obscureText: _obscureText,
                  enabled: !controller.saving,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-...',
                    suffixIcon: IconButton(
                      tooltip: _obscureText ? '显示' : '隐藏',
                      onPressed: () => setState(() {
                        _obscureText = !_obscureText;
                      }),
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (controller.error case final error?) ...[
                  const SizedBox(height: 10),
                  Text(
                    error,
                    style: TextStyle(
                      color: SparkColors.of(context).danger,
                      fontSize: SparkFontSizes.footnote,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (controller.configured)
                      TextButton.icon(
                        key: const ValueKey('delete-deepseek-api-key'),
                        onPressed: controller.saving ? null : _delete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('删除'),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      key: const ValueKey('save-deepseek-api-key'),
                      onPressed: controller.saving ? null : _save,
                      icon: controller.saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_outlined),
                      label: const Text('验证并保存'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    final success = await widget.controller.save(_textController.text);
    if (!mounted || !success) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('DeepSeek API Key 已保存')),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 API Key？'),
        content: const Text('删除后，ChatPaper 和中文翻译将无法调用 DeepSeek。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-deepseek-api-key'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await widget.controller.delete();
    if (!mounted || !success) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('DeepSeek API Key 已删除')),
    );
  }
}
