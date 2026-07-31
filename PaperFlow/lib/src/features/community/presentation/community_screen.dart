import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/theme/paperflow_theme.dart';
import '../../../core/widgets/paper_diagram.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../domain/community_post.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _feedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PaperFlowColors.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _CommunityFilters(
                  feedIndex: _feedIndex,
                  onFeedSelected: (index) => setState(() => _feedIndex = index),
                ),
              ),
            ),
            Expanded(
              child: MasonryGridView.count(
                key: const ValueKey('community-feed'),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
                itemCount: demoCommunityPosts.length,
                itemBuilder: (context, index) => _DiscoveryCard(
                  post: demoCommunityPosts[index],
                  index: index,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityFilters extends StatelessWidget {
  const _CommunityFilters({
    required this.feedIndex,
    required this.onFeedSelected,
  });

  final int feedIndex;
  final ValueChanged<int> onFeedSelected;

  static const feeds = ['关注', '热门', '最新'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 53,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < feeds.length; index++) ...[
            GestureDetector(
              onTap: () => onFeedSelected(index),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _CommunityFilterLabel(
                  label: feeds[index],
                  selected: feedIndex == index,
                ),
              ),
            ),
            if (index < feeds.length - 1) const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }
}

class _CommunityFilterLabel extends StatelessWidget {
  const _CommunityFilterLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: selected ? PaperFlowColors.primary : PaperFlowColors.muted,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: selected ? 24 : 0,
          height: 3,
          decoration: BoxDecoration(
            color: PaperFlowColors.primary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 5),
      ],
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

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final title = post.paperTitle ?? post.attachment ?? post.content;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaperFlowColors.line),
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
                  style: const TextStyle(
                    color: PaperFlowColors.ink,
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
                    style: const TextStyle(
                      color: PaperFlowColors.muted,
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
                        style: const TextStyle(
                          color: PaperFlowColors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _liked = !_liked),
                      child: Icon(
                        _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _liked
                            ? PaperFlowColors.primary
                            : PaperFlowColors.muted,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      post.likes,
                      style: const TextStyle(
                        color: PaperFlowColors.muted,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                  color: PaperFlowColors.primary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              const PaperDiagram(accent: PaperFlowColors.purple),
            ],
          ),
        1 => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded,
                  color: PaperFlowColors.primary, size: 26),
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
                  color: PaperFlowColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'RESEARCH\nNOTES',
                  style: TextStyle(
                    color: PaperFlowColors.ink,
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
              const Text(
                'WEEKLY READING',
                style: TextStyle(
                  color: PaperFlowColors.blue,
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
                            ? PaperFlowColors.primary
                            : PaperFlowColors.blue.withValues(alpha: 0.35),
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
