import 'package:flutter/material.dart';

import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';
import '../../../../core/theme/spark_theme.dart';
import '../../domain/arxiv_subject_catalog.dart';
import '../../domain/paper_channel.dart';
import '../../domain/paper_conference_catalog.dart';

Future<void> showPaperChannelManagerSheet(
  BuildContext context, {
  required List<UserPaperChannel> userChannels,
  required ValueChanged<List<UserPaperChannel>> onChannelsChanged,
  bool showConferenceChannels = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SparkColors.of(context).card,
    builder: (sheetContext) => PaperChannelManagerSheet(
      userChannels: userChannels,
      onChannelsChanged: onChannelsChanged,
      showConferenceChannels: showConferenceChannels,
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
    this.showConferenceChannels = false,
    this.bottomPadding = 0,
  });

  final List<UserPaperChannel> userChannels;
  final ValueChanged<List<UserPaperChannel>> onChannelsChanged;
  final bool showConferenceChannels;
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
                  Expanded(
                    child: Text(
                      '频道管理',
                      style: TextStyle(
                        color: SparkColors.of(context).ink,
                        fontSize: SparkFontSizes.titleSmall,
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
                length: widget.showConferenceChannels ? 2 : 1,
                child: Column(
                  children: [
                    TabBar(
                      key: const ValueKey('paper-channel-manager-tabs'),
                      labelColor: SparkColors.of(context).ink,
                      unselectedLabelColor: SparkColors.of(context).muted,
                      indicatorColor: SparkColors.of(context).primary,
                      labelStyle: const TextStyle(
                        fontSize: SparkFontSizes.bodySmall,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: [
                        const Tab(text: '主题'),
                        if (widget.showConferenceChannels)
                          const Tab(text: '会议'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          SingleChildScrollView(
                            key: const ValueKey('paper-channel-subject-page'),
                            padding: const EdgeInsets.fromLTRB(
                              SparkDesignTokens.space5,
                              SparkDesignTokens.space1,
                              SparkDesignTokens.space5,
                              SparkDesignTokens.space5,
                            ),
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
                          if (widget.showConferenceChannels)
                            SingleChildScrollView(
                              key: const ValueKey(
                                'paper-channel-conference-page',
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                SparkDesignTokens.space5,
                                SparkDesignTokens.space1,
                                SparkDesignTokens.space5,
                                SparkDesignTokens.space5,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final conference
                                      in PaperConferenceCatalog.conferences)
                                    _ConferenceRow(
                                      conference: conference,
                                      added: _isConferenceAdded(conference.id),
                                      onToggle: () =>
                                          _toggleConference(conference),
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

  bool _isConferenceAdded(String id) => _channels.any(
        (channel) =>
            channel.kind == PaperChannelKind.conference && channel.id == id,
      );

  void _toggleConference(PaperConference conference) {
    setState(() {
      if (_isConferenceAdded(conference.id)) {
        _channels.removeWhere(
          (channel) =>
              channel.kind == PaperChannelKind.conference &&
              channel.id == conference.id,
        );
      } else {
        _channels.add(
          UserPaperChannel(
            kind: PaperChannelKind.conference,
            id: conference.id,
            displayName: conference.displayName,
          ),
        );
      }
    });
    _publish();
  }

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
        style: TextStyle(
          color: SparkColors.of(context).muted,
          fontSize: SparkFontSizes.caption,
        ),
      ),
      trailing: Icon(
        added ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
        color: added
            ? SparkColors.of(context).primary
            : SparkColors.of(context).muted,
        size: 20,
      ),
    );
  }
}

class _ConferenceRow extends StatelessWidget {
  const _ConferenceRow({
    required this.conference,
    required this.added,
    required this.onToggle,
  });

  final PaperConference conference;
  final bool added;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('paper-channel-conference-${conference.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: onToggle,
      title: Text(conference.displayName),
      subtitle: Text(
        '会议频道',
        style: TextStyle(
          color: SparkColors.of(context).muted,
          fontSize: SparkFontSizes.caption,
        ),
      ),
      trailing: Icon(
        added ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
        color: added
            ? SparkColors.of(context).primary
            : SparkColors.of(context).muted,
        size: 20,
      ),
    );
  }
}
