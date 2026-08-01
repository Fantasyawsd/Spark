import 'package:flutter/material.dart';

import '../../application/paper_ai_service.dart';
import '../../application/paper_ai_session_repository.dart';
import '../../application/paper_comment_controller.dart';
import '../../application/paper_interaction_controller.dart';
import '../../application/paper_link_service.dart';
import '../../application/paper_reading_controller.dart';
import '../../application/paper_share_service.dart';
import '../../application/paper_translation_service.dart';
import '../../domain/paper.dart';
import 'paper_comments_sheet.dart';
import 'paper_favorite_group_sheet.dart';
import 'paper_reader_card.dart';

/// Connects the shared paper reader UI to paper controllers and services.
class PaperReaderView extends StatelessWidget {
  const PaperReaderView({
    super.key,
    required this.paper,
    required this.interactionController,
    required this.commentController,
    required this.readingController,
    required this.aiService,
    required this.translationServiceFactory,
    this.webSearchAiService,
    this.aiSessionRepository,
    this.translationRepository,
    this.shareService,
    this.linkService,
    this.onOpenRelatedPaper,
    this.contentTopInset = 8,
    this.actionBarBottomInset = 72,
  });

  final Paper paper;
  final PaperInteractionController interactionController;
  final PaperCommentController commentController;
  final PaperReadingController readingController;
  final PaperAiService aiService;
  final PaperAiService? webSearchAiService;
  final PaperAiSessionRepository? aiSessionRepository;
  final PaperTranslationServiceFactory translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final PaperShareService? shareService;
  final PaperLinkService? linkService;
  final ValueChanged<String>? onOpenRelatedPaper;
  final double contentTopInset;
  final double actionBarBottomInset;

  @override
  Widget build(BuildContext context) {
    return PaperReaderCard(
      paper: paper,
      liked: interactionController.isLiked(paper.id),
      saved: interactionController.isSaved(paper.id),
      read: readingController.isRead(paper.id),
      readLater: readingController.isReadLater(paper.id),
      followed: interactionController.isAuthorFollowed(paper),
      shareCountDelta: interactionController.shareCountDelta(paper.id),
      commentCountDelta: commentController.commentCount(paper.id),
      onLike: () => interactionController.toggleLike(paper.id),
      onSave: () => interactionController.toggleSave(paper.id),
      onSaveLongPress: () => _showFavoriteGroups(context),
      onToggleRead: () => readingController.toggleRead(paper.id),
      onToggleReadLater: () => readingController.toggleReadLater(paper.id),
      onFollow: () => interactionController.toggleFollowAuthor(paper),
      onComment: () => _openDiscussion(context),
      onAnalyze: () => _openDiscussion(
        context,
        initialPage: PaperSheetPage.ai,
      ),
      onShare: () => _sharePaper(context),
      onOpenPaper:
          linkService == null ? null : (uri) => _openPaperLink(context, uri),
      onOpenRelatedPaper: onOpenRelatedPaper,
      initialTabIndex: readingController.tabIndex(paper.id),
      initialAbstractScrollOffset:
          readingController.abstractScrollOffset(paper.id),
      onTabChanged: (index) => readingController.selectTab(paper.id, index),
      onAbstractScrollChanged: (offset) =>
          readingController.saveAbstractScrollOffset(paper.id, offset),
      translationServiceFactory: translationServiceFactory,
      translationRepository: translationRepository,
      contentTopInset: contentTopInset,
      actionBarBottomInset: actionBarBottomInset,
    );
  }

  void _openDiscussion(
    BuildContext context, {
    PaperSheetPage initialPage = PaperSheetPage.comments,
  }) {
    showPaperCommentsSheet(
      context,
      paper,
      initialPage: initialPage,
      aiService: aiService,
      webSearchAiService: webSearchAiService,
      aiSessionRepository: aiSessionRepository,
      commentController: commentController,
    );
  }

  void _showFavoriteGroups(BuildContext context) {
    showPaperFavoriteGroupSheet(
      context,
      paperId: paper.id,
      controller: interactionController,
    );
  }

  Future<void> _openPaperLink(BuildContext context, Uri uri) async {
    final service = linkService;
    if (service == null) return;
    try {
      final opened = await service.open(uri);
      if (!opened && context.mounted) {
        _showMessage(context, '无法打开论文链接');
      }
    } catch (_) {
      if (context.mounted) _showMessage(context, '无法打开论文链接');
    }
  }

  Future<void> _sharePaper(BuildContext context) async {
    final service = shareService;
    if (service == null) return;
    try {
      final result = await service.share(PaperShareComposer.compose(paper));
      if (!context.mounted || result == PaperShareResult.cancelled) return;
      interactionController.recordShare(paper.id);
      if (result == PaperShareResult.copied) {
        _showMessage(context, '分享内容已复制');
      }
    } on PaperShareException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
