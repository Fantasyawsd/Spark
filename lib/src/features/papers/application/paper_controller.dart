import 'package:flutter/foundation.dart';

import '../domain/paper.dart';
import '../domain/paper_catalog.dart';
import '../domain/paper_channel.dart';
import '../domain/paper_channel_preference_repository.dart';
import '../domain/paper_interaction_repository.dart';
import '../domain/paper_preference_repository.dart';
import '../domain/paper_repository.dart';
import 'paper_feed_controller.dart';
import 'paper_interaction_controller.dart';

/// Compatibility facade that owns the two independent paper controllers.
class PaperController extends ChangeNotifier {
  PaperController(
    PaperRepository repository, {
    PaperInteractionRepository? interactionRepository,
    PaperPreferenceRepository? preferenceRepository,
    PaperCatalogRepository? catalogRepository,
    PaperChannelPreferenceRepository? channelPreferenceRepository,
    Iterable<String> Function()? readPaperIdsProvider,
  }) : this._fromPapers(
          repository.getAll(),
          interactionRepository: interactionRepository,
          preferenceRepository: preferenceRepository,
          catalogRepository: catalogRepository,
          channelPreferenceRepository: channelPreferenceRepository,
          readPaperIdsProvider: readPaperIdsProvider,
        );

  PaperController._fromPapers(
    List<Paper> papers, {
    PaperInteractionRepository? interactionRepository,
    PaperPreferenceRepository? preferenceRepository,
    PaperCatalogRepository? catalogRepository,
    PaperChannelPreferenceRepository? channelPreferenceRepository,
    Iterable<String> Function()? readPaperIdsProvider,
  })  : feed = PaperFeedController.fromPapers(
          papers,
          preferenceRepository: preferenceRepository,
          catalogRepository: catalogRepository,
          channelPreferenceRepository: channelPreferenceRepository,
          readPaperIdsProvider: readPaperIdsProvider,
        ),
        interactions = PaperInteractionController(
          repository: interactionRepository,
        ) {
    feed.addListener(notifyListeners);
    interactions.addListener(_handleInteractionsChanged);
  }

  final PaperFeedController feed;
  final PaperInteractionController interactions;

  List<Paper> get papers => feed.papers;
  List<UserPaperChannel> get userChannels => feed.userChannels;
  int get channelCount => feed.channelCount;
  int get channelIndex => feed.channelIndex;
  int get primaryCategoryIndex => feed.primaryCategoryIndex;
  int get currentPaperIndex => feed.currentPaperIndex;
  bool get gridMode => feed.gridMode;

  Future<void> initialize() async {
    await Future.wait([
      interactions.initialize(),
      feed.initializePreferences(),
    ]);
    await feed.initializeChannels();
    await feed.initializeCatalog();
  }

  Future<void> reloadLocalState() async {
    await Future.wait([
      interactions.reload(),
      feed.reloadPreferences(),
    ]);
  }

  bool isLiked(String paperId) => interactions.isLiked(paperId);
  bool isSaved(String paperId) => interactions.isSaved(paperId);
  bool isFollowed(String paperId) => interactions.isFollowed(paperId);
  int shareCountDelta(String paperId) => interactions.shareCountDelta(paperId);

  void toggleGridMode() => feed.toggleGridMode();
  void openPaper(int index) => feed.openPaper(index);
  void openPaperById(String paperId) => feed.openPaperById(paperId);
  void selectPaper(int index) => feed.selectPaper(index);
  void selectPrimaryCategory(int index) => feed.selectPrimaryCategory(index);
  void selectChannel(int index) => feed.selectChannel(index);
  Future<void> saveUserChannels(List<UserPaperChannel> channels) =>
      feed.saveUserChannels(channels);
  void toggleLike(String paperId) => interactions.toggleLike(paperId);
  void toggleSave(String paperId) => interactions.toggleSave(paperId);
  void toggleFollow(String paperId) => interactions.toggleFollow(paperId);
  void recordShare(String paperId) => interactions.recordShare(paperId);

  void _handleInteractionsChanged() {
    feed.setFollowedPaperIds(interactions.followedPaperIds);
    notifyListeners();
  }

  @override
  void dispose() {
    feed.removeListener(notifyListeners);
    interactions.removeListener(_handleInteractionsChanged);
    feed.dispose();
    interactions.dispose();
    super.dispose();
  }
}
