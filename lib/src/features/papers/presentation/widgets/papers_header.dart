import 'package:flutter/material.dart';

import '../../../../core/theme/spark_theme.dart';
import '../../../../core/widgets/cherry_primitives.dart';

/// Discovery controls are separated into identity, channels and filters.
class PapersHeader extends StatelessWidget {
  const PapersHeader({
    super.key,
    required this.channels,
    required this.selectedIndex,
    required this.onChannelSelected,
    required this.onManageChannels,
    required this.onSearch,
    required this.timeRangeLabel,
    required this.onSelectTimeRange,
    required this.gridMode,
    required this.onToggleViewMode,
  });

  static const fixedChannelLabels = ['推荐', '关注', '最新'];
  static const height = 144.0;

  final List<String> channels;
  final int selectedIndex;
  final ValueChanged<int> onChannelSelected;
  final VoidCallback onManageChannels;
  final VoidCallback onSearch;
  final String timeRangeLabel;
  final VoidCallback onSelectTimeRange;
  final bool gridMode;
  final VoidCallback onToggleViewMode;

  @override
  Widget build(BuildContext context) {
    final palette = SparkColors.of(context);
    return Material(
      color: palette.canvas,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: palette.primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('spark · 灵光',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SparkTheme.editorialTitle(context, size: 25)),
                  ),
                  CherryIconButton(
                    tooltip: '搜索',
                    icon: Icons.search_rounded,
                    onPressed: onSearch,
                    size: 40,
                    iconSize: 24,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('paper-channel-bar'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var index = 0; index < channels.length; index++)
                            Semantics(
                              selected: selectedIndex == index,
                              button: true,
                              child: InkWell(
                                key: ValueKey('paper-channel-$index'),
                                onTap: () => onChannelSelected(index),
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minWidth: 48),
                                  height: 48,
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(
                                      width: 2,
                                      color: selectedIndex == index
                                          ? palette.primary
                                          : Colors.transparent,
                                    )),
                                  ),
                                  child: Text(
                                    channels[index],
                                    style: TextStyle(
                                      color: selectedIndex == index
                                          ? palette.ink
                                          : palette.muted,
                                      fontSize: 15,
                                      fontWeight: selectedIndex == index
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      fontFamily:
                                          SparkTheme.platformCjkFontFamily(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  CherryIconButton(
                    key: const ValueKey('paper-channel-manage'),
                    tooltip: '管理频道',
                    icon: Icons.add_rounded,
                    onPressed: onManageChannels,
                    iconSize: 22,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey('paper-time-filter'),
                        onPressed: onSelectTimeRange,
                        icon: const Icon(Icons.tune_rounded, size: 17),
                        label: Text(timeRangeLabel,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        style: TextButton.styleFrom(
                          foregroundColor: palette.muted,
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('papers-view-mode-toggle'),
                    onPressed: onToggleViewMode,
                    icon: Icon(
                        gridMode
                            ? Icons.view_agenda_outlined
                            : Icons.grid_view_rounded,
                        size: 17),
                    label: Text(gridMode ? '阅读视图' : '网格视图'),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.muted,
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
