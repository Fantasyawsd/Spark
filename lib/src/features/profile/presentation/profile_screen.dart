import 'package:flutter/material.dart';

import '../../../core/theme/spark_theme.dart';
import '../../papers/papers.dart';
import 'favorite_collection_section.dart';
import 'paper_shelf_list_screen.dart';
import 'paper_shelf_section.dart';
import 'profile_header.dart';
import 'profile_settings_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    this.aiSettingsBuilder,
    this.catalogStatus,
    this.favoriteGroups = const [FavoriteGroup.defaultGroup()],
    this.favoritePapersByGroup = const {},
    this.savedCount = 0,
    this.readingHistory = const [],
    this.readLaterPapers = const [],
    this.localDataListenable,
    this.localDataDescriptionBuilder,
    this.onOpenLocalData,
    this.onOpenFavoriteCollection,
    this.onOpenReadLaterCollection,
    this.onOpenReadingHistory,
    this.onOpenPaper,
    this.onCreateFavoriteGroup,
    this.onRenameFavoriteGroup,
    this.onDeleteFavoriteGroup,
  });

  final WidgetBuilder? aiSettingsBuilder;
  final PaperCatalogStatusView? catalogStatus;
  final List<FavoriteGroup> favoriteGroups;
  final Map<String, List<Paper>> favoritePapersByGroup;
  final int savedCount;
  final List<Paper> readingHistory;
  final List<Paper> readLaterPapers;
  final Listenable? localDataListenable;
  final String Function()? localDataDescriptionBuilder;
  final VoidCallback? onOpenLocalData;
  final VoidCallback? onOpenFavoriteCollection;
  final VoidCallback? onOpenReadLaterCollection;
  final VoidCallback? onOpenReadingHistory;
  final ValueChanged<String>? onOpenPaper;
  final ValueChanged<String>? onCreateFavoriteGroup;
  final void Function(String groupId, String name)? onRenameFavoriteGroup;
  final ValueChanged<String>? onDeleteFavoriteGroup;

  @override
  Widget build(BuildContext context) {
    final status = catalogStatus;
    return ColoredBox(
      color: SparkColors.canvas,
      child: SafeArea(
        bottom: false,
        child: ListView(
          key: const ValueKey('profile-scroll'),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 94),
          children: [
            ProfileHeader(
              savedCount: savedCount,
              readLaterCount: readLaterPapers.length,
              historyCount: readingHistory.length,
              onSavedTap: () => _openFavorites(context),
              onReadLaterTap: () => _openReadLater(context),
              onHistoryTap: () => _openHistory(context),
            ),
            if (aiSettingsBuilder case final builder?) ...[
              const SizedBox(height: 16),
              builder(context),
            ],
            const SizedBox(height: 14),
            FavoriteCollectionSection(
              groups: favoriteGroups,
              papersByGroup: favoritePapersByGroup,
              onOpenPaper: onOpenPaper,
              onCreateGroup: onCreateFavoriteGroup,
              onRenameGroup: onRenameFavoriteGroup,
              onDeleteGroup: onDeleteFavoriteGroup,
            ),
            const SizedBox(height: 14),
            PaperShelfSection(
              icon: Icons.watch_later_outlined,
              title: '稍后阅读',
              emptyText: '还没有稍后阅读的论文',
              keyPrefix: 'profile-read-later-paper',
              papers: readLaterPapers,
              onOpenPaper: onOpenPaper,
              onViewAll: () => _openReadLater(context),
            ),
            const SizedBox(height: 14),
            PaperShelfSection(
              icon: Icons.schedule_rounded,
              title: '阅读历史',
              emptyText: '还没有阅读记录',
              keyPrefix: 'profile-history-paper',
              papers: readingHistory,
              onOpenPaper: onOpenPaper,
              onViewAll: () => _openHistory(context),
            ),
            const SizedBox(height: 14),
            ProfileSettingsSection(
              catalogSourceDescription: status?.description,
              catalogStateLabel: status?.stateLabel,
              catalogOffline:
                  status?.availability == PaperCatalogAvailability.offline,
              fallbackLocalDataDescription:
                  '收藏 $savedCount · 稍后阅读 ${readLaterPapers.length} · '
                  '阅读历史 ${readingHistory.length}',
              localDataListenable: localDataListenable,
              localDataDescriptionBuilder: localDataDescriptionBuilder,
              onOpenLocalData: onOpenLocalData,
            ),
          ],
        ),
      ),
    );
  }

  void _openFavorites(BuildContext context) {
    final callback = onOpenFavoriteCollection;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PaperShelfListScreen.collection(
          title: '我的收藏',
          groups: favoriteGroups,
          papersByGroup: favoritePapersByGroup,
          onOpenPaper: onOpenPaper ?? (_) {},
        ),
      ),
    );
  }

  void _openReadLater(BuildContext context) {
    final callback = onOpenReadLaterCollection;
    if (callback != null) {
      callback();
      return;
    }
    _openFlatList(context, title: '稍后阅读', papers: readLaterPapers);
  }

  void _openHistory(BuildContext context) {
    final callback = onOpenReadingHistory;
    if (callback != null) {
      callback();
      return;
    }
    _openFlatList(context, title: '阅读历史', papers: readingHistory);
  }

  void _openFlatList(
    BuildContext context, {
    required String title,
    required List<Paper> papers,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PaperShelfListScreen.flat(
          title: title,
          papers: papers,
          onOpenPaper: onOpenPaper ?? (_) {},
        ),
      ),
    );
  }
}

class PaperCatalogStatusView {
  const PaperCatalogStatusView({
    required this.sourceLabel,
    required this.availability,
    this.fetchedAt,
  });

  final String sourceLabel;
  final PaperCatalogAvailability availability;
  final DateTime? fetchedAt;

  String get stateLabel => switch (availability) {
        PaperCatalogAvailability.online => '在线',
        PaperCatalogAvailability.offline => '离线',
        PaperCatalogAvailability.local => '本地',
      };

  String get description {
    final updated = fetchedAt;
    if (updated == null) return sourceLabel;
    final local = updated.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$sourceLabel · $month-$day $hour:$minute 更新';
  }
}

enum PaperCatalogAvailability { online, offline, local }
