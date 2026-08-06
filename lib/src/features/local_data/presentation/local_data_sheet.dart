import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/spark_theme.dart';
import '../../../core/widgets/spark_sheet.dart';
import '../application/local_data_controller.dart';
import '../domain/local_data_repository.dart';

Future<void> showLocalDataSheet(
  BuildContext context, {
  required LocalDataController controller,
}) {
  unawaited(controller.refresh());
  return showSparkSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => LocalDataSheet(controller: controller),
  );
}

class LocalDataSheet extends StatelessWidget {
  const LocalDataSheet({super.key, required this.controller});

  final LocalDataController controller;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              children: [
                const SparkSheetHandle(height: 18),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 10, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '本地数据',
                          style: TextStyle(
                            color: SparkColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('local-data-close'),
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _UsageSummary(
                        usage: controller.usage,
                        loading: controller.loading,
                      ),
                      const SizedBox(height: 18),
                      _DataAction(
                        key: const ValueKey('local-data-clear-paper-cache'),
                        icon: Icons.description_outlined,
                        title: '论文缓存',
                        subtitle: '远程论文目录与中文解读缓存',
                        size: controller.usage.paperCacheBytes,
                        enabled: !controller.mutating,
                        onTap: () => _confirmAndRun(
                          context,
                          target: LocalDataClearTarget.paperCache,
                        ),
                      ),
                      _DataAction(
                        key: const ValueKey('local-data-clear-chats'),
                        icon: Icons.forum_outlined,
                        title: 'ChatPaper 对话',
                        subtitle: '主聊天与每篇论文的 AI 对话',
                        size: controller.usage.chatBytes,
                        enabled: !controller.mutating,
                        onTap: () => _confirmAndRun(
                          context,
                          target: LocalDataClearTarget.chats,
                        ),
                      ),
                      _DataAction(
                        icon: Icons.bookmarks_outlined,
                        title: '阅读与互动',
                        subtitle: '收藏、评论、阅读记录、筛选与搜索历史',
                        size: controller.usage.businessDataBytes,
                        enabled: true,
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        key: const ValueKey('local-data-reset-all'),
                        onPressed: controller.mutating
                            ? null
                            : () => _confirmAndRun(
                                  context,
                                  target: LocalDataClearTarget.allBusinessData,
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB42318),
                          side: const BorderSide(color: Color(0xFFF0B4AE)),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('重置本地业务数据'),
                      ),
                      if (controller.mutating) ...[
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      if (controller.error case final error?) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required LocalDataClearTarget target,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ClearConfirmationDialog(target: target),
    );
    if (confirmed != true || !context.mounted) return;
    final succeeded = switch (target) {
      LocalDataClearTarget.paperCache => await controller.clearPaperCache(),
      LocalDataClearTarget.chats => await controller.clearChats(),
      LocalDataClearTarget.allBusinessData =>
        await controller.resetAllBusinessData(),
    };
    if (!context.mounted || !succeeded) return;
    final message = switch (target) {
      LocalDataClearTarget.paperCache => '论文缓存已清理',
      LocalDataClearTarget.chats => 'ChatPaper 对话已清除',
      LocalDataClearTarget.allBusinessData => '本地业务数据已重置',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UsageSummary extends StatelessWidget {
  const _UsageSummary({required this.usage, required this.loading});

  final LocalDataUsage usage;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SparkColors.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SparkColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.storage_rounded, color: SparkColors.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '已使用空间',
                style: TextStyle(
                  color: SparkColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                formatLocalDataBytes(usage.totalBytes),
                key: const ValueKey('local-data-total-size'),
                style: const TextStyle(
                  color: SparkColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DataAction extends StatelessWidget {
  const _DataAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.size,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int size;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: SparkColors.ink),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatLocalDataBytes(size),
            style: const TextStyle(color: SparkColors.muted),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ],
      ),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}

class _ClearConfirmationDialog extends StatelessWidget {
  const _ClearConfirmationDialog({required this.target});

  final LocalDataClearTarget target;

  @override
  Widget build(BuildContext context) {
    final (title, message, action) = switch (target) {
      LocalDataClearTarget.paperCache => (
          '清理论文缓存？',
          '缓存会在后续联网浏览和翻译时重新生成。',
          '清理',
        ),
      LocalDataClearTarget.chats => (
          '清除 ChatPaper 对话？',
          '主聊天和所有论文 AI 对话将从当前设备删除。',
          '清除',
        ),
      LocalDataClearTarget.allBusinessData => (
          '重置本地业务数据？',
          '收藏、阅读记录、评论、搜索历史、ChatPaper 对话和论文缓存将被删除。DeepSeek API Key 不受影响。',
          '重置',
        ),
    };
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('local-data-confirm'),
          onPressed: () => Navigator.pop(context, true),
          style: target == LocalDataClearTarget.allBusinessData
              ? FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB42318),
                )
              : null,
          child: Text(action),
        ),
      ],
    );
  }
}

String formatLocalDataBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
}
