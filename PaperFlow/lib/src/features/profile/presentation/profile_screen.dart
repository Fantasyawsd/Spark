import 'package:flutter/material.dart';

import '../../../core/theme/paperflow_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/paperflow_sheet.dart';
import '../../../core/widgets/surface_card.dart';
import '../../ai_settings/application/deepseek_credential_controller.dart';
import '../../papers/domain/favorite_group.dart';
import '../../papers/domain/paper.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.credentialController,
    this.favoriteGroups = const [FavoriteGroup.defaultGroup()],
    this.favoritePapersByGroup = const {},
    this.savedCount = 0,
    this.readingHistory = const [],
    this.readLaterPapers = const [],
    this.onOpenPaper,
    this.onCreateFavoriteGroup,
    this.onRenameFavoriteGroup,
    this.onDeleteFavoriteGroup,
  });

  final DeepSeekCredentialController? credentialController;
  final List<FavoriteGroup> favoriteGroups;
  final Map<String, List<Paper>> favoritePapersByGroup;
  final int savedCount;
  final List<Paper> readingHistory;
  final List<Paper> readLaterPapers;
  final ValueChanged<String>? onOpenPaper;
  final ValueChanged<String>? onCreateFavoriteGroup;
  final void Function(String groupId, String name)? onRenameFavoriteGroup;
  final ValueChanged<String>? onDeleteFavoriteGroup;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PaperFlowColors.canvas,
      child: SafeArea(
        bottom: false,
        child: ListView(
          key: const ValueKey('profile-scroll'),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 94),
          children: [
            _ProfileHeader(
              savedCount: savedCount,
              readLaterCount: readLaterPapers.length,
              historyCount: readingHistory.length,
            ),
            if (credentialController case final controller?) ...[
              const SizedBox(height: 16),
              _DeepSeekSettingsCard(controller: controller),
            ],
            const SizedBox(height: 14),
            _FavoritesCard(
              groups: favoriteGroups,
              papersByGroup: favoritePapersByGroup,
              onOpenPaper: onOpenPaper,
              onCreateGroup: onCreateFavoriteGroup,
              onRenameGroup: onRenameFavoriteGroup,
              onDeleteGroup: onDeleteFavoriteGroup,
            ),
            const SizedBox(height: 14),
            _PaperShelfCard(
              icon: Icons.watch_later_outlined,
              title: '稍后阅读',
              emptyText: '还没有稍后阅读的论文',
              keyPrefix: 'profile-read-later-paper',
              papers: readLaterPapers,
              onOpenPaper: onOpenPaper,
            ),
            const SizedBox(height: 14),
            _ReadingHistoryCard(
              papers: readingHistory,
              onOpenPaper: onOpenPaper,
            ),
            const SizedBox(height: 14),
            _AppSettingsCard(
              savedCount: savedCount,
              readLaterCount: readLaterPapers.length,
              historyCount: readingHistory.length,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.savedCount,
    required this.readLaterCount,
    required this.historyCount,
  });

  final int savedCount;
  final int readLaterCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '我的研究库',
                style: TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('profile-theme-settings'),
              tooltip: '主题',
              onPressed: () => showPaperThemeSheet(context),
              icon: const Icon(Icons.palette_outlined),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '本地论文、阅读记录与 AI 配置',
          style: TextStyle(color: PaperFlowColors.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _ProfileStat(value: '$savedCount', label: '收藏'),
            const _StatDivider(),
            _ProfileStat(value: '$readLaterCount', label: '稍后阅读'),
            const _StatDivider(),
            _ProfileStat(value: '$historyCount', label: '阅读历史'),
          ],
        ),
      ],
    );
  }
}

class _DeepSeekSettingsCard extends StatelessWidget {
  const _DeepSeekSettingsCard({required this.controller});

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
                      ? PaperFlowColors.primarySoft
                      : PaperFlowColors.canvas,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.key_rounded,
                  color: configured
                      ? PaperFlowColors.primary
                      : PaperFlowColors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DeepSeek API',
                      style: TextStyle(
                        color: PaperFlowColors.ink,
                        fontSize: 15,
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
                      style: const TextStyle(
                        color: PaperFlowColors.muted,
                        fontSize: 12,
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
  return showPaperFlowSheet<void>(
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
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                const PaperFlowSheetHandle(height: 22),
                const Text(
                  'DeepSeek API 设置',
                  style: TextStyle(
                    color: PaperFlowColors.ink,
                    fontSize: 18,
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
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
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

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              style: const TextStyle(
                  color: PaperFlowColors.muted, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
        height: 37,
        child: VerticalDivider(width: 1, color: PaperFlowColors.line));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.icon, required this.title, this.action = '查看全部'});

  final IconData icon;
  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: PaperFlowColors.muted, size: 21),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ),
        if (action.isNotEmpty) ...[
          Text(
            action,
            style: const TextStyle(
              color: PaperFlowColors.muted,
              fontSize: 11.5,
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: PaperFlowColors.muted,
            size: 19,
          ),
        ],
      ],
    );
  }
}

class _FavoritesCard extends StatefulWidget {
  const _FavoritesCard({
    required this.groups,
    required this.papersByGroup,
    required this.onOpenPaper,
    required this.onCreateGroup,
    required this.onRenameGroup,
    required this.onDeleteGroup,
  });

  final List<FavoriteGroup> groups;
  final Map<String, List<Paper>> papersByGroup;
  final ValueChanged<String>? onOpenPaper;
  final ValueChanged<String>? onCreateGroup;
  final void Function(String groupId, String name)? onRenameGroup;
  final ValueChanged<String>? onDeleteGroup;

  @override
  State<_FavoritesCard> createState() => _FavoritesCardState();
}

class _FavoritesCardState extends State<_FavoritesCard> {
  String _selectedGroupId = defaultFavoriteGroupId;

  @override
  void didUpdateWidget(covariant _FavoritesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.groups.any((group) => group.id == _selectedGroupId)) {
      _selectedGroupId = defaultFavoriteGroupId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final papers = widget.papersByGroup[_selectedGroupId] ?? const <Paper>[];
    final selectedGroup = widget.groups.firstWhere(
      (group) => group.id == _selectedGroupId,
      orElse: () => const FavoriteGroup.defaultGroup(),
    );
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  icon: Icons.bookmark_rounded,
                  title: '我的收藏',
                  action: '',
                ),
              ),
              IconButton(
                key: const ValueKey('profile-create-favorite-group'),
                tooltip: '新建收藏分组',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onCreateGroup == null ? null : _createGroup,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
              if (!selectedGroup.isDefault)
                PopupMenuButton<_FavoriteGroupAction>(
                  key: const ValueKey('profile-manage-favorite-group'),
                  tooltip: '管理当前分组',
                  onSelected: (action) => _manageGroup(action, selectedGroup),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _FavoriteGroupAction.rename,
                      child: Text('重命名'),
                    ),
                    PopupMenuItem(
                      value: _FavoriteGroupAction.delete,
                      child: Text('删除分组'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final group = widget.groups[index];
                final selected = group.id == _selectedGroupId;
                final count = widget.papersByGroup[group.id]?.length ?? 0;
                return ChoiceChip(
                  key: ValueKey('profile-favorite-group-${group.id}'),
                  selected: selected,
                  label: Text('${group.name} $count'),
                  onSelected: (_) => setState(() {
                    _selectedGroupId = group.id;
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          if (papers.isEmpty)
            SizedBox(
              height: 72,
              child: Center(
                child: Text(
                  selectedGroup.isDefault ? '还没有收藏论文' : '这个分组还是空的',
                  style: const TextStyle(
                    color: PaperFlowColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: papers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (context, index) {
                  final paper = papers[index];
                  return InkWell(
                    key: ValueKey('profile-saved-paper-${paper.id}'),
                    onTap: widget.onOpenPaper == null
                        ? null
                        : () => widget.onOpenPaper!(paper.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 224,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PaperFlowColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paper.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PaperFlowColors.ink,
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            paper.venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PaperFlowColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = await _requestFavoriteGroupName(context, title: '新建收藏分组');
    if (name != null) widget.onCreateGroup?.call(name);
  }

  Future<void> _manageGroup(
    _FavoriteGroupAction action,
    FavoriteGroup group,
  ) async {
    switch (action) {
      case _FavoriteGroupAction.rename:
        final name = await _requestFavoriteGroupName(
          context,
          title: '重命名分组',
          initialValue: group.name,
        );
        if (name != null) widget.onRenameGroup?.call(group.id, name);
      case _FavoriteGroupAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除收藏分组？'),
            content: const Text('只会删除这个分组，不会删除论文或其他分组中的收藏。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('confirm-delete-favorite-group'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed == true) widget.onDeleteGroup?.call(group.id);
    }
  }
}

enum _FavoriteGroupAction { rename, delete }

Future<String?> _requestFavoriteGroupName(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) async {
  var value = initialValue;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        key: const ValueKey('profile-favorite-group-name-input'),
        initialValue: initialValue,
        autofocus: true,
        maxLength: 24,
        decoration: const InputDecoration(hintText: '例如：重点阅读'),
        onChanged: (input) => value = input,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('confirm-profile-favorite-group-name'),
          onPressed: () {
            final normalized = value.trim();
            if (normalized.isNotEmpty) Navigator.pop(context, normalized);
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
  return result;
}

class _ReadingHistoryCard extends StatelessWidget {
  const _ReadingHistoryCard({required this.papers, required this.onOpenPaper});

  final List<Paper> papers;
  final ValueChanged<String>? onOpenPaper;

  @override
  Widget build(BuildContext context) {
    return _PaperShelfCard(
      icon: Icons.schedule_rounded,
      title: '阅读历史',
      emptyText: '还没有阅读记录',
      keyPrefix: 'profile-history-paper',
      papers: papers,
      onOpenPaper: onOpenPaper,
    );
  }
}

class _PaperShelfCard extends StatelessWidget {
  const _PaperShelfCard({
    required this.icon,
    required this.title,
    required this.emptyText,
    required this.keyPrefix,
    required this.papers,
    required this.onOpenPaper,
  });

  final IconData icon;
  final String title;
  final String emptyText;
  final String keyPrefix;
  final List<Paper> papers;
  final ValueChanged<String>? onOpenPaper;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SectionHeader(
            icon: icon,
            title: title,
            action: papers.isEmpty ? '' : '共 ${papers.length} 篇',
          ),
          const SizedBox(height: 14),
          if (papers.isEmpty)
            SizedBox(
              height: 72,
              child: Center(
                child: Text(
                  emptyText,
                  style: const TextStyle(
                    color: PaperFlowColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: papers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (context, index) {
                  final paper = papers[index];
                  return InkWell(
                    key: ValueKey('$keyPrefix-${paper.id}'),
                    onTap: onOpenPaper == null
                        ? null
                        : () => onOpenPaper!(paper.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 224,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PaperFlowColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paper.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PaperFlowColors.ink,
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            paper.venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PaperFlowColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AppSettingsCard extends StatelessWidget {
  const _AppSettingsCard({
    required this.savedCount,
    required this.readLaterCount,
    required this.historyCount,
  });

  final int savedCount;
  final int readLaterCount;
  final int historyCount;

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
                  style: const TextStyle(color: PaperFlowColors.muted),
                ),
              ),
              onTap: () => showPaperThemeSheet(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('本地数据'),
              subtitle: Text(
                '收藏 $savedCount · 稍后阅读 $readLaterCount · 阅读历史 $historyCount',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('隐私'),
              subtitle: const Text('阅读、互动与聊天数据保存在当前设备'),
            ),
            const Divider(height: 1),
            ListTile(
              key: const ValueKey('profile-open-source-licenses'),
              leading: const Icon(Icons.article_outlined),
              title: const Text('开源许可'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'PaperFlow',
                applicationVersion: '1.0.0 (1)',
              ),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('PaperFlow'),
              trailing: Text(
                '1.0.0 (1)',
                style: TextStyle(color: PaperFlowColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 打开设置底部面板，目前提供主题色切换。
void showPaperThemeSheet(BuildContext context) {
  showPaperFlowSheet<void>(
    context: context,
    builder: (context) => Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: PaperFlowColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '设置',
              style: TextStyle(
                color: PaperFlowColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '主题色',
              style: TextStyle(
                color: PaperFlowColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: ThemeController.instance,
              builder: (context, _) {
                final current = ThemeController.instance.color;
                return Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: PaperThemeColor.values.map((c) {
                    final selected = c == current;
                    return GestureDetector(
                      onTap: () => ThemeController.instance.setColor(c),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c.value,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? PaperFlowColors.ink
                                    : PaperFlowColors.line,
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A15213A),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: selected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            c.label,
                            style: TextStyle(
                              color: selected
                                  ? PaperFlowColors.ink
                                  : PaperFlowColors.muted,
                              fontSize: 10,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
