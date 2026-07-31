import 'package:flutter/material.dart';

import '../../../../core/motion/motion_tokens.dart';
import '../../../../core/theme/paperflow_theme.dart';
import '../../../../core/widgets/paperflow_sheet.dart';
import '../../../../core/widgets/paperflow_tab_bar.dart';
import '../../domain/paper.dart';

enum PaperSheetPage { comments, ai }

Future<void> showPaperCommentsSheet(
  BuildContext context,
  PaperRecord paper, {
  PaperSheetPage initialPage = PaperSheetPage.comments,
}) {
  return showPaperFlowSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: const Color(0x660B1020),
    builder: (context) => _PaperCommentsSheet(
      paper: paper,
      initialPage: initialPage,
    ),
  );
}

class _PaperCommentsSheet extends StatefulWidget {
  const _PaperCommentsSheet({
    required this.paper,
    required this.initialPage,
  });

  final PaperRecord paper;
  final PaperSheetPage initialPage;

  @override
  State<_PaperCommentsSheet> createState() => _PaperCommentsSheetState();
}

class _PaperCommentsSheetState extends State<_PaperCommentsSheet> {
  final TextEditingController _composerController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  late final PageController _pageController;

  late int _pageIndex;
  bool _sending = false;
  bool _fullscreen = false;

  final List<_CommentData> _comments = [
    const _CommentData(
      name: 'Lin Zhang',
      initials: 'LZ',
      time: '2小时前',
      location: '北京',
      body: 'LoRA 最有价值的地方是把每个任务的增量参数压缩到了很小，部署多个下游任务时优势尤其明显。',
      likes: 86,
      replies: 12,
      color: Color(0xFF3F7CCF),
    ),
    const _CommentData(
      name: 'Yuki',
      initials: 'YK',
      time: '5小时前',
      location: '上海',
      body: '论文里的秩 r 并不是越大越好。实际使用时，先从 8 或 16 开始做消融通常更稳妥。',
      likes: 42,
      replies: 6,
      color: Color(0xFF8A5CC7),
    ),
    const _CommentData(
      name: 'Chen Wei',
      initials: 'CW',
      time: '昨天',
      location: '杭州',
      body: '推荐结合 QLoRA 一起看，一个解决低秩参数化，另一个进一步压缩基座模型显存。',
      likes: 31,
      replies: 3,
      color: Color(0xFF2F9B78),
    ),
    const _CommentData(
      name: 'Mira',
      initials: 'M',
      time: '2天前',
      location: '深圳',
      body: '有没有人在视觉模型上比较过不同目标层的效果？只加在 attention 上和同时加 MLP 的差异值得讨论。',
      likes: 18,
      replies: 5,
      color: Color(0xFFDF6D4F),
    ),
  ];

  final List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.initialPage.index;
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void dispose() {
    _composerController.dispose();
    _sheetController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          final fullscreen = notification.extent > 0.75;
          if (fullscreen != _fullscreen) {
            setState(() => _fullscreen = fullscreen);
          }
          return false;
        },
        child: DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.50,
          minChildSize: 0.50,
          maxChildSize: 1.0,
          snap: true,
          snapSizes: const [0.50, 1.0],
          shouldCloseOnMinExtent: false,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              key: const ValueKey('paper-comments-sheet'),
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  const PaperFlowSheetHandle(),
                  _SheetHeader(
                    pageIndex: _pageIndex,
                    commentCount: widget.paper.comments,
                    fullscreen: _fullscreen,
                    pageController: _pageController,
                    onPageSelected: _selectPage,
                    onFullscreen: _toggleFullscreen,
                    onClose: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: PageView(
                      key: const ValueKey('paper-sheet-pages'),
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) =>
                          setState(() => _pageIndex = index),
                      children: [
                        ListView(
                          key: const PageStorageKey('paper-comments-page'),
                          controller: _pageIndex == 0 ? scrollController : null,
                          padding: EdgeInsets.zero,
                          children: [
                            _CommentsContent(comments: _comments),
                          ],
                        ),
                        ListView(
                          key: const PageStorageKey('paper-ai-page'),
                          controller: _pageIndex == 1 ? scrollController : null,
                          padding: EdgeInsets.zero,
                          children: [
                            _AiAnalysisContent(
                              paper: widget.paper,
                              messages: _messages,
                              sending: _sending,
                              onPrompt: _sendText,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _MessageComposer(
                    controller: _composerController,
                    aiMode: _pageIndex == 1,
                    enabled: !_sending,
                    onChanged: (_) => setState(() {}),
                    onSend: () => _sendText(_composerController.text),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleFullscreen() async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      _fullscreen ? 0.50 : 1.0,
      duration: MotionTokens.duration(context, MotionTokens.sheetDuration),
      curve: MotionTokens.pageCurve,
    );
  }

  void _selectPage(int index) {
    if (index == _pageIndex || !_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: MotionTokens.duration(context, MotionTokens.tabDuration),
      curve: MotionTokens.pageCurve,
    );
  }

  Future<void> _sendText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _sending) return;
    _composerController.clear();

    if (_pageIndex == 0) {
      setState(() {
        _comments.insert(
          0,
          _CommentData(
            name: 'Alex Chen',
            initials: 'AC',
            time: '刚刚',
            location: '北京',
            body: text,
            likes: 0,
            replies: 0,
            color: PaperFlowColors.primary,
          ),
        );
      });
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(fromUser: true, text: text));
      _sending = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(fromUser: false, text: _answerFor(text)));
      _sending = false;
    });
  }

  String _answerFor(String question) {
    if (question.contains('实验') || question.contains('效果')) {
      return '论文在多个自然语言理解与生成任务上比较了全量微调和参数高效方法。LoRA 只训练少量低秩参数，也能保持接近全量微调的效果，同时显著降低显存与存储开销。';
    }
    if (question.contains('区别') || question.contains('QLoRA')) {
      return 'LoRA 冻结基座权重并训练低秩增量矩阵；QLoRA 在此基础上将冻结的基座模型量化到 4-bit，因此进一步降低了微调显存。';
    }
    return 'LoRA 假设模型适配任务时的权重变化具有较低的内在秩，因此把大矩阵更新分解为两个更小的矩阵，只训练这部分增量参数。';
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.pageIndex,
    required this.commentCount,
    required this.fullscreen,
    required this.pageController,
    required this.onPageSelected,
    required this.onFullscreen,
    required this.onClose,
  });

  final int pageIndex;
  final String commentCount;
  final bool fullscreen;
  final PageController pageController;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onFullscreen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 16, right: 6),
      color: Colors.white,
      child: Row(
        children: [
          SizedBox(
            width: 184,
            child: PaperFlowTabBar(
              tabs: ['评论 $commentCount', 'AI 解析'],
              selectedIndex: pageIndex,
              pageController: pageController,
              height: 44,
              indicatorWidth: 56,
              textSize: 15,
              onSelected: onPageSelected,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: fullscreen ? '恢复半屏' : '全屏',
            onPressed: onFullscreen,
            icon: Icon(
              fullscreen
                  ? Icons.close_fullscreen_rounded
                  : Icons.open_in_full_rounded,
              size: 21,
            ),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 23),
          ),
        ],
      ),
    );
  }
}

class _CommentsContent extends StatelessWidget {
  const _CommentsContent({required this.comments});

  final List<_CommentData> comments;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          for (var index = 0; index < comments.length; index++)
            _EntryAnimation(
              key: ValueKey('${comments[index].time}-${comments[index].body}'),
              child: _CommentTile(comment: comments[index]),
            ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  const _CommentTile({required this.comment});

  final _CommentData comment;

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: comment.color.withValues(alpha: 0.14),
            child: Text(
              comment.initials,
              style: TextStyle(
                color: comment.color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.name,
                  style: const TextStyle(
                    color: PaperFlowColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: const TextStyle(
                    color: PaperFlowColors.ink,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${comment.time} · ${comment.location}',
                      style: const TextStyle(
                        color: PaperFlowColors.subtle,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      '回复',
                      style: TextStyle(
                        color: PaperFlowColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _liked = !_liked),
                      child: Row(
                        children: [
                          Icon(
                            _liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: _liked
                                ? PaperFlowColors.primary
                                : PaperFlowColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.likes + (_liked ? 1 : 0)}',
                            style: const TextStyle(
                              color: PaperFlowColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (comment.replies > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                          width: 20, height: 1, color: PaperFlowColors.line),
                      const SizedBox(width: 8),
                      Text(
                        '展开 ${comment.replies} 条回复',
                        style: const TextStyle(
                          color: PaperFlowColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: PaperFlowColors.muted, size: 17),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiAnalysisContent extends StatelessWidget {
  const _AiAnalysisContent({
    required this.paper,
    required this.messages,
    required this.sending,
    required this.onPrompt,
  });

  final PaperRecord paper;
  final List<_ChatMessage> messages;
  final bool sending;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    const prompts = ['解释核心方法', '总结实验结果', '与 QLoRA 的区别'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '这篇论文提出 LoRA：冻结预训练模型参数，并在 Transformer 层中注入可训练的低秩矩阵。它显著减少了可训练参数和显存占用，同时保持接近全量微调的任务效果。',
            style: const TextStyle(
              color: PaperFlowColors.ink,
              fontSize: 15,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '内容由 AI 生成，仅供参考',
            style: TextStyle(color: PaperFlowColors.subtle, fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              _AnalysisTool(icon: Icons.thumb_down_alt_outlined),
              _AnalysisTool(icon: Icons.copy_rounded),
              _AnalysisTool(icon: Icons.reply_rounded),
              _AnalysisTool(icon: Icons.refresh_rounded),
              _AnalysisTool(icon: Icons.volume_up_outlined),
            ],
          ),
          const SizedBox(height: 18),
          ...prompts.map(
            (prompt) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: InkWell(
                onTap: sending ? null : () => onPrompt(prompt),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: PaperFlowColors.canvas,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: PaperFlowColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          prompt,
                          style: const TextStyle(
                            color: PaperFlowColors.ink,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (messages.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 10),
            ...messages.map(
              (message) => _EntryAnimation(
                key: ValueKey('${message.fromUser}-${message.text}'),
                child: _MessageBubble(message: message),
              ),
            ),
          ],
          if (sending) const _TypingIndicator(),
        ],
      ),
    );
  }
}

class _AnalysisTool extends StatelessWidget {
  const _AnalysisTool({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: PaperFlowColors.canvas,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: PaperFlowColors.muted, size: 20),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: message.fromUser
              ? PaperFlowColors.primary
              : PaperFlowColors.canvas,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.fromUser ? Colors.white : PaperFlowColors.ink,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(10),
      child: SizedBox(
        width: 17,
        height: 17,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _EntryAnimation extends StatelessWidget {
  const _EntryAnimation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MotionTokens.duration(
      context,
      MotionTokens.pageDuration,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: MotionTokens.enterCurve,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.aiMode,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool aiMode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = enabled && controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          color: Colors.white,
          child: TextField(
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            onSubmitted: (_) {
              if (canSend) onSend();
            },
            textInputAction: TextInputAction.send,
            minLines: 1,
            maxLines: 1,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: aiMode ? '问 AI 或按住说话' : '有价值的讨论更容易被看见',
              hintStyle: const TextStyle(
                color: PaperFlowColors.subtle,
                fontSize: 13,
              ),
              prefixIcon: aiMode
                  ? const Icon(Icons.auto_awesome_rounded,
                      color: PaperFlowColors.ink, size: 20)
                  : null,
              suffixIcon: canSend
                  ? IconButton(
                      tooltip: '发送',
                      onPressed: onSend,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    )
                  : Icon(
                      aiMode
                          ? Icons.graphic_eq_rounded
                          : Icons.sentiment_satisfied_alt_rounded,
                      color: PaperFlowColors.muted,
                      size: 22,
                    ),
              filled: true,
              fillColor: PaperFlowColors.canvas,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _CommentData {
  const _CommentData({
    required this.name,
    required this.initials,
    required this.time,
    required this.location,
    required this.body,
    required this.likes,
    required this.replies,
    required this.color,
  });

  final String name;
  final String initials;
  final String time;
  final String location;
  final String body;
  final int likes;
  final int replies;
  final Color color;
}

class _ChatMessage {
  const _ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}
