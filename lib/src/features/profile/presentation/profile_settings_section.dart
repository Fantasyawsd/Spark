import 'package:flutter/material.dart';

import '../../../core/config/app_version.dart';
import '../../../core/theme/spark_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/surface_card.dart';
import 'profile_theme_sheet.dart';

class ProfileSettingsSection extends StatelessWidget {
  const ProfileSettingsSection({
    super.key,
    required this.catalogSourceDescription,
    required this.catalogStateLabel,
    required this.catalogOffline,
    required this.fallbackLocalDataDescription,
    this.localDataListenable,
    this.localDataDescriptionBuilder,
    this.onOpenLocalData,
  });

  final String? catalogSourceDescription;
  final String? catalogStateLabel;
  final bool catalogOffline;
  final String fallbackLocalDataDescription;
  final Listenable? localDataListenable;
  final String Function()? localDataDescriptionBuilder;
  final VoidCallback? onOpenLocalData;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              key: const ValueKey('profile-theme-row'),
              leading: const Icon(Icons.palette_outlined),
              title: const Text('主题'),
              trailing: ListenableBuilder(
                listenable: ThemeController.instance,
                builder: (context, _) => Text(
                  ThemeController.instance.color.label,
                  style: TextStyle(color: SparkColors.of(context).muted),
                ),
              ),
              onTap: () => showProfileThemeSheet(context),
            ),
            const Divider(height: 1),
            if (catalogSourceDescription case final description?) ...[
              ListTile(
                key: const ValueKey('profile-paper-source'),
                leading: const Icon(Icons.cloud_outlined),
                title: const Text('论文数据源'),
                subtitle: Text(description),
                trailing: Text(
                  catalogStateLabel ?? '',
                  style: TextStyle(
                    color: catalogOffline
                        ? SparkColors.of(context).warning
                        : SparkColors.of(context).muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
            ListTile(
              key: const ValueKey('profile-local-data'),
              leading: const Icon(Icons.storage_outlined),
              title: const Text('本地数据'),
              subtitle: _buildLocalDataDescription(),
              trailing: onOpenLocalData == null
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              onTap: onOpenLocalData,
            ),
            const Divider(height: 1),
            ListTile(
              key: const ValueKey('profile-privacy'),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('隐私'),
              subtitle: const Text('了解本地存储与 DeepSeek 数据传输'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showPrivacyNotice(context),
            ),
            const Divider(height: 1),
            ListTile(
              key: const ValueKey('profile-open-source-licenses'),
              leading: const Icon(Icons.article_outlined),
              title: const Text('开源许可'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Spark',
                applicationVersion: AppVersion.current.display,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Spark'),
              trailing: Text(
                AppVersion.current.display,
                style: TextStyle(color: SparkColors.of(context).muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalDataDescription() {
    final builder = localDataDescriptionBuilder;
    final listenable = localDataListenable;
    if (builder == null) return Text(fallbackLocalDataDescription);
    if (listenable == null) return Text(builder());
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => Text(builder()),
    );
  }
}

Future<void> _showPrivacyNotice(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('隐私说明'),
      content: SingleChildScrollView(
        child: Text(
          '论文缓存、阅读记录、点赞、收藏、评论、搜索历史、中文解读和 ChatPaper 会话保存在当前设备。你可以在“本地数据”中分类清理。\n\n'
          '使用 ChatPaper 或中文解读时，你输入的内容、当前论文的标题、摘要和必要上下文会发送到 DeepSeek 官方接口生成回答。开启联网搜索后，DeepSeek 还会处理搜索请求并返回来源。\n\n'
          'DeepSeek API Key 由系统安全存储保护，不写入普通业务数据文件，也不会随“重置本地业务数据”一起删除；你可以在 AI 设置中单独删除。\n\n'
          'Spark ${AppVersion.current.name} 不提供账号、广告或分析统计。打开论文、PDF 或来源链接时，将跳转到系统浏览器并受对应第三方服务的隐私规则约束。',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
