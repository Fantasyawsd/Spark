import 'package:flutter/material.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/paperflow_sheet.dart';
import '../../application/paper_interaction_controller.dart';

Future<void> showPaperFavoriteGroupSheet(
  BuildContext context, {
  required String paperId,
  required PaperInteractionController controller,
}) {
  return showPaperFlowSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _PaperFavoriteGroupSheet(
      paperId: paperId,
      controller: controller,
    ),
  );
}

class _PaperFavoriteGroupSheet extends StatefulWidget {
  const _PaperFavoriteGroupSheet({
    required this.paperId,
    required this.controller,
  });

  final String paperId;
  final PaperInteractionController controller;

  @override
  State<_PaperFavoriteGroupSheet> createState() =>
      _PaperFavoriteGroupSheetState();
}

class _PaperFavoriteGroupSheetState extends State<_PaperFavoriteGroupSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(covariant _PaperFavoriteGroupSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleChanged);
    widget.controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.controller.favoriteGroups;
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PaperFlowSheetHandle(height: 18),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 10, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '收藏到分组',
                        style: TextStyle(
                          color: PaperFlowColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final selected = widget.controller.isSavedInGroup(
                      widget.paperId,
                      group.id,
                    );
                    return CheckboxListTile(
                      key: ValueKey('favorite-group-${group.id}'),
                      value: selected,
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: Icon(
                        group.isDefault
                            ? Icons.bookmark_rounded
                            : Icons.folder_outlined,
                        color: selected
                            ? PaperFlowColors.primary
                            : PaperFlowColors.muted,
                      ),
                      title: Text(group.name),
                      onChanged: (value) {
                        widget.controller.setFavoriteMembership(
                          paperId: widget.paperId,
                          groupId: group.id,
                          selected: value ?? false,
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('create-favorite-group'),
                    onPressed: _createGroup,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('新建分组'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = await _requestGroupName(context);
    if (name == null || !mounted) return;
    final groupId = widget.controller.createFavoriteGroup(name);
    widget.controller.setFavoriteMembership(
      paperId: widget.paperId,
      groupId: groupId,
      selected: true,
    );
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }
}

Future<String?> _requestGroupName(
  BuildContext context, {
  String initialValue = '',
  String title = '新建收藏分组',
}) async {
  var value = initialValue;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        key: const ValueKey('favorite-group-name-input'),
        initialValue: initialValue,
        autofocus: true,
        maxLength: 24,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: '例如：重点阅读'),
        onChanged: (input) => value = input,
        onFieldSubmitted: (input) {
          if (input.trim().isNotEmpty) Navigator.pop(context, input.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('confirm-create-favorite-group'),
          onPressed: () {
            final normalized = value.trim();
            if (normalized.isNotEmpty) Navigator.pop(context, normalized);
          },
          child: const Text('创建'),
        ),
      ],
    ),
  );
  return result;
}
