import 'package:flutter/material.dart';

import '../../../../core/theme/paperflow_theme.dart';
import '../../domain/arxiv_subject_catalog.dart';
import '../../domain/paper_channel.dart';

Future<void> showPaperChannelManagerSheet(
  BuildContext context, {
  required List<UserPaperChannel> userChannels,
  required ValueChanged<List<UserPaperChannel>> onChannelsChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PaperFlowColors.card,
    builder: (sheetContext) => PaperChannelManagerSheet(
      userChannels: userChannels,
      onChannelsChanged: onChannelsChanged,
      // 底部导航遮挡预留
      bottomPadding: MediaQuery.of(context).padding.bottom,
    ),
  );
}

class PaperChannelManagerSheet extends StatefulWidget {
  const PaperChannelManagerSheet({
    super.key,
    required this.userChannels,
    required this.onChannelsChanged,
    this.bottomPadding = 0,
  });

  final List<UserPaperChannel> userChannels;
  final ValueChanged<List<UserPaperChannel>> onChannelsChanged;
  final double bottomPadding;

  @override
  State<PaperChannelManagerSheet> createState() =>
      _PaperChannelManagerSheetState();
}

class _PaperChannelManagerSheetState extends State<PaperChannelManagerSheet> {
  late List<UserPaperChannel> _channels;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _channels = List.of(widget.userChannels);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '频道管理',
                      style: TextStyle(
                        color: PaperFlowColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('paper-channel-manager-close'),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('paper-channel-manager-body'),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_channels.isNotEmpty) ...[
                      const _SectionTitle('已添加频道'),
                      ReorderableListView.builder(
                        key: const ValueKey('paper-channel-added-list'),
                        shrinkWrap: true,
                        buildDefaultDragHandles: true,
                        itemCount: _channels.length,
                        onReorderItem: _handleReorder,
                        itemBuilder: (context, index) {
                          final channel = _channels[index];
                          return ListTile(
                            key: ValueKey(
                                'paper-channel-added-${channel.storageKey}'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: const Icon(
                                Icons.drag_indicator_rounded,
                                color: PaperFlowColors.muted,
                                size: 18,
                              ),
                            ),
                            title: Text(channel.displayName),
                            subtitle: Text(
                              channel.id,
                              style: const TextStyle(
                                color: PaperFlowColors.muted,
                                fontSize: 11,
                              ),
                            ),
                            trailing: IconButton(
                              key: ValueKey(
                                'paper-channel-remove-${channel.storageKey}',
                              ),
                              tooltip: '移除频道',
                              onPressed: () => _removeChannel(channel),
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                color: PaperFlowColors.muted,
                                size: 19,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    const _SectionTitle('按主题'),
                    TextField(
                      key: const ValueKey('paper-channel-search'),
                      decoration: const InputDecoration(
                        hintText: '搜索 arXiv 主题',
                        isDense: true,
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: 6),
                    for (final subject in ArxivSubjectCatalog.search(_query))
                      _SubjectRow(
                        subject: subject,
                        added: _isAdded(subject.code),
                        onToggle: () => _toggleSubject(subject),
                      ),
                    if (ArxivSubjectCatalog.search(_query).isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '没有匹配的主题。',
                          style: TextStyle(
                            color: PaperFlowColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const _SectionTitle('按会议'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '会议频道尚未开放，真实会议数据源接入后可编辑。',
                        style: TextStyle(
                          color: PaperFlowColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isAdded(String code) => _channels.any(
        (channel) =>
            channel.kind == PaperChannelKind.subject && channel.id == code,
      );

  void _toggleSubject(ArxivSubject subject) {
    setState(() {
      if (_isAdded(subject.code)) {
        _channels.removeWhere(
          (channel) =>
              channel.kind == PaperChannelKind.subject &&
              channel.id == subject.code,
        );
      } else {
        _channels.add(
          UserPaperChannel(
            kind: PaperChannelKind.subject,
            id: subject.code,
            displayName: subject.displayName,
          ),
        );
      }
    });
    _publish();
  }

  void _removeChannel(UserPaperChannel channel) {
    setState(() => _channels.remove(channel));
    _publish();
  }

  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      final channel = _channels.removeAt(oldIndex);
      _channels.insert(newIndex, channel);
    });
    _publish();
  }

  void _publish() {
    widget.onChannelsChanged(List.of(_channels));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: PaperFlowColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.added,
    required this.onToggle,
  });

  final ArxivSubject subject;
  final bool added;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('paper-channel-subject-${subject.code}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: onToggle,
      title: Text(subject.displayName),
      subtitle: Text(
        subject.code,
        style: const TextStyle(
          color: PaperFlowColors.muted,
          fontSize: 11,
        ),
      ),
      trailing: Icon(
        added ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
        color: added ? PaperFlowColors.primary : PaperFlowColors.muted,
        size: 20,
      ),
    );
  }
}
