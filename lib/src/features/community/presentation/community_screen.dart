import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/motion/motion_tokens.dart';
import '../../../core/theme/spark_theme.dart';
import '../../../core/widgets/spark_tab_bar.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../domain/community_post.dart';
import 'widgets/paper_diagram.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key, required this.posts});

  final List<CommunityPost> posts;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _feedIndex = 1;
  late final PageController _feedController;

  @override
  void initState() {
    super.initState();
    _feedController = PageController(initialPage: _feedIndex);
  }

  @override
  void dispose() {
    _feedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SparkColors.of(context).canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: _CommunityFilters(
                feedIndex: _feedIndex,
                pageController: _feedController,
                onFeedSelected: _selectFeed,
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _feedController,
                itemCount: _CommunityFilters.feeds.length,
                onPageChanged: (index) => setState(() => _feedIndex = index),
                itemBuilder: (context, feedIndex) => MasonryGridView.count(
                  key: ValueKey('community-feed-$feedIndex'),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 92),
                  itemCount: widget.posts.length,
                  itemBuilder: (context, index) =>
                      _DiscoveryCard(post: widget.posts[index], index: index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectFeed(int index) {
    if (index == _feedIndex || !_feedController.hasClients) return;
    _feedController.animateToPage(
      index,
      duration: MotionTokens.duration(context, MotionTokens.tabDuration),
      curve: MotionTokens.pageCurve,
    );
  }
}

class _CommunityFilters extends StatelessWidget {
  const _CommunityFilters({
    required this.feedIndex,
    required this.pageController,
    required this.onFeedSelected,
  });

  final int feedIndex;
  final PageController pageController;
  final ValueChanged<int> onFeedSelected;

  static const feeds = ['关注', '热门', '最新'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: SparkTabBar(
        tabs: feeds,
        selectedIndex: feedIndex,
        pageController: pageController,
        height: 44,
        indicatorWidth: 24,
        selectedColor: SparkColors.of(context).ink,
        indicatorColor: SparkColors.of(context).ink,
        textSize: 13,
        onSelected: onFeedSelected,
      ),
    );
  }
}

class _DiscoveryCard extends StatefulWidget {
  const _DiscoveryCard({required this.post, required this.index});

  final CommunityPost post;
  final int index;

  @override
  State<_DiscoveryCard> createState() => _DiscoveryCardState();
}

class _DiscoveryCardState extends State<_DiscoveryCard> {
  bool _liked = false;
  bool _likePressed = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final title = post.paperTitle ?? post.attachment ?? post.content;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SparkColors.of(context).line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E15213A),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AcademicCover(post: post, index: widget.index),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: post.paperTitle != null ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SparkColors.of(context).ink,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (post.paperTitle != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SparkColors.of(context).muted,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Row(
                  children: [
                    ProfileAvatar(imageUrl: post.avatarUrl, radius: 11),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        post.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SparkColors.of(context).muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleLike,
                        child: Center(
                          child: AnimatedScale(
                            scale: _likePressed ? 0.86 : 1,
                            duration: MotionTokens.duration(
                              context,
                              MotionTokens.feedbackDuration,
                            ),
                            curve: MotionTokens.pageCurve,
                            child: AnimatedSwitcher(
                              duration: MotionTokens.duration(
                                context,
                                MotionTokens.feedbackDuration,
                              ),
                              child: Icon(
                                _liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                key: ValueKey(_liked),
                                color: _liked
                                    ? SparkColors.of(context).primary
                                    : SparkColors.of(context).muted,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (post.likes.trim() != '0') ...[
                      const SizedBox(width: 3),
                      Text(
                        post.likes,
                        style: TextStyle(
                          color: SparkColors.of(context).muted,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likePressed = true;
    });
    Future<void>.delayed(MotionTokens.feedbackDuration, () {
      if (mounted) setState(() => _likePressed = false);
    });
  }
}

class _AcademicCover extends StatelessWidget {
  const _AcademicCover({required this.post, required this.index});

  final CommunityPost post;
  final int index;

  @override
  Widget build(BuildContext context) {
    final height = switch (index % 4) {
      0 => 126.0,
      1 => 154.0,
      2 => 112.0,
      _ => 138.0,
    };
    final colors = <List<Color>>[
      [const Color(0xFFE8E1FF), const Color(0xFFF8F6FF)],
      [const Color(0xFF111827), const Color(0xFF27324A)],
      [const Color(0xFFFFE5EB), const Color(0xFFFFF8FA)],
      [const Color(0xFFDFF4FF), const Color(0xFFF5FBFF)],
    ][index % 4];

    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: switch (index % 4) {
        0 => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.venue ?? 'PAPER NOTE',
                style: TextStyle(
                  color: SparkColors.of(context).primary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              PaperDiagram(accent: SparkColors.of(context).purple),
            ],
          ),
        1 => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: SparkColors.of(context).primary,
                size: 26,
              ),
              const Spacer(),
              Text(
                post.tags.first.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'IDEAS WORTH DISCUSSING',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        2 => Row(
            children: [
              Container(
                width: 52,
                height: 70,
                decoration: BoxDecoration(
                  color: SparkColors.of(context).primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'RESEARCH\nNOTES',
                  style: TextStyle(
                    color: SparkColors.of(context).ink,
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        _ => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WEEKLY READING',
                style: TextStyle(
                  color: SparkColors.of(context).blue,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (bar) {
                  return Expanded(
                    child: Container(
                      height: 24.0 + bar * 13,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: bar == 3
                            ? SparkColors.of(context).primary
                            : SparkColors.of(
                                context,
                              ).blue.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
      },
    );
  }
}
