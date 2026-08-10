import 'package:flutter/material.dart';

import '../../../core/theme/spark_design_tokens.dart';
import '../../../core/theme/spark_font_sizes.dart';
import '../../../core/theme/spark_theme.dart';
import '../../../core/widgets/surface_card.dart';
import '../../papers/papers.dart';
import 'profile_section_header.dart';

class FavoriteCollectionSection extends StatefulWidget {
  const FavoriteCollectionSection({
    super.key,
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
  State<FavoriteCollectionSection> createState() =>
      _FavoriteCollectionSectionState();
}

class _FavoriteCollectionSectionState extends State<FavoriteCollectionSection> {
  String _selectedGroupId = defaultFavoriteGroupId;

  @override
  void didUpdateWidget(covariant FavoriteCollectionSection oldWidget) {
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
                child: ProfileSectionHeader(
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
                    color: SparkColors.muted,
                    fontSize: SparkFontSizes.bodySmall,
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
                  return _FavoritePaperTile(
                    paper: paper,
                    onTap: widget.onOpenPaper == null
                        ? null
                        : () => widget.onOpenPaper!(paper.id),
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

class _FavoritePaperTile extends StatelessWidget {
  const _FavoritePaperTile({required this.paper, required this.onTap});

  final Paper paper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('profile-saved-paper-${paper.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
      child: Container(
        width: 224,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(SparkDesignTokens.radiusLg),
          border: Border.all(color: SparkColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paper.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SparkColors.ink,
                fontSize: SparkFontSizes.bodySmall,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              paper.venue ??
                  paper.journalReference ??
                  (paper.source == 'arxiv' ? 'arXiv' : paper.source),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SparkColors.muted,
                fontSize: SparkFontSizes.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FavoriteGroupAction { rename, delete }

Future<String?> _requestFavoriteGroupName(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) async {
  var value = initialValue;
  return showDialog<String>(
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
}
