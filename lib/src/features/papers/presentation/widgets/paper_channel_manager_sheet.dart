import 'package:flutter/material.dart';

import '../../../../core/theme/spark_theme.dart';
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
    backgroundColor: SparkColors.card,
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
                        color: SparkColors.ink,
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
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      key: const ValueKey('paper-channel-manager-tabs'),
                      labelColor: SparkColors.ink,
                      unselectedLabelColor: SparkColors.muted,
                      indicatorColor: SparkColors.primary,
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: const [
                        Tab(text: '主题'),
                        Tab(text: '会议'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          SingleChildScrollView(
                            key: const ValueKey('paper-channel-subject-page'),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final subject
                                    in ArxivSubjectCatalog.initialSubjects)
                                  _SubjectRow(
                                    subject: subject,
                                    added: _isAdded(subject.code),
                                    onToggle: () => _toggleSubject(subject),
                                  ),
                              ],
                            ),
                          ),
                          SingleChildScrollView(
                            key:
                                const ValueKey('paper-channel-conference-page'),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '会议频道尚未开放，真实会议数据源接入后可编辑。',
                                  style: TextStyle(
                                    color: SparkColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  void _publish() {
    widget.onChannelsChanged(List.of(_channels));
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
          color: SparkColors.muted,
          fontSize: 11,
        ),
      ),
      trailing: Icon(
        added ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
        color: added ? SparkColors.primary : SparkColors.muted,
        size: 20,
      ),
    );
  }
}
