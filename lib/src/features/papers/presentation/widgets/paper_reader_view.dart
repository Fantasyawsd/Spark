import 'package:flutter/material.dart';

import '../../../../core/diagnostics/diagnostics.dart';
import '../../../chat/chat.dart';
import '../../application/paper_comment_controller.dart';
import '../../application/paper_interaction_controller.dart';
import '../../application/paper_keyword_service.dart';
import '../../application/paper_reading_controller.dart';
import '../../application/paper_share_service.dart';
import '../../application/paper_translation_service.dart';
import '../../domain/paper.dart';
import '../../domain/paper_keyword_repository.dart';
import '../../domain/paper_link_service.dart';
import '../../domain/paper_share.dart';
import '../paper_ai_discussion_builder.dart';
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
    required this.aiDiscussionBuilder,
    required this.keywordService,
    required this.translationServiceFactory,
    this.translationRepository,
    this.keywordRepository,
    this.shareService,
    this.linkService,
    this.onOpenRelatedPaper,
    this.active = true,
    this.contentTopInset = 8,
    this.actionBarBottomInset = 72,
  });

  final Paper paper;
  final PaperInteractionController interactionController;
  final PaperCommentController commentController;
  final PaperReadingController readingController;
  final PaperAiDiscussionBuilder aiDiscussionBuilder;
  final ChatAiService keywordService;
  final PaperTranslationServiceFactory translationServiceFactory;
  final PaperTranslationRepository? translationRepository;
  final PaperKeywordRepository? keywordRepository;
  final PaperShareService? shareService;
  final PaperLinkService? linkService;
  final ValueChanged<String>? onOpenRelatedPaper;
  final bool active;
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
      active: active,
      initialAbstractScrollOffset:
          readingController.abstractScrollOffset(paper.id),
      onAbstractScrollChanged: (offset) =>
          readingController.saveAbstractScrollOffset(paper.id, offset),
      translationServiceFactory: translationServiceFactory,
      translationRepository: translationRepository,
      keywordService: keywordService,
      keywordRepository: keywordRepository,
      contentTopInset: contentTopInset,
      actionBarBottomInset: actionBarBottomInset,
    );
  }

  Future<void> _openDiscussion(
    BuildContext context, {
    PaperSheetPage initialPage = PaperSheetPage.comments,
  }) async {
    List<String> keywords;
    try {
      keywords = await _loadGeneratedKeywords();
    } on Object catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.paperReaderKeywordsLoad,
        error: error,
        stackTrace: stackTrace,
        severity: SparkDiagnosticSeverity.warning,
      );
      if (!context.mounted) return;
      _showMessage(context, '无法读取已生成的关键词，已使用空关键词继续');
      keywords = const [];
    }
    if (!context.mounted) return;
    showPaperCommentsSheet(
      context,
      paper,
      initialPage: initialPage,
      aiDiscussionBuilder: aiDiscussionBuilder,
      commentController: commentController,
      generatedKeywords: keywords,
    );
  }

  Future<List<String>> _loadGeneratedKeywords() async {
    final record = await keywordRepository?.load(paper.id);
    if (record == null || !isPaperKeywordRecordFresh(record, paper)) {
      return const [];
    }
    return record.keywords;
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
    } on Object catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.paperReaderOpenLink,
        error: error,
        stackTrace: stackTrace,
        severity: SparkDiagnosticSeverity.warning,
      );
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
    } on PaperShareException catch (error, stackTrace) {
      SparkDiagnostics.reportUnexpected(
        operation: SparkDiagnosticOperation.paperReaderShare,
        error: error,
        stackTrace: stackTrace,
        severity: SparkDiagnosticSeverity.warning,
      );
      if (context.mounted) _showMessage(context, error.message);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
