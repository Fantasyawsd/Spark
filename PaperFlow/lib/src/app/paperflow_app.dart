import 'package:flutter/material.dart';

import '../core/theme/paperflow_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/widgets/paperflow_bottom_nav.dart';
import '../core/widgets/paperflow_sheet.dart';
import '../features/community/presentation/community_screen.dart';
import '../features/messages/presentation/messages_screen.dart';
import '../features/papers/application/paper_controller.dart';
import '../features/papers/data/demo_paper_repository.dart';
import '../features/papers/presentation/papers_screen.dart';
import '../features/profile/presentation/profile_screen.dart';

class PaperFlowApp extends StatelessWidget {
  const PaperFlowApp({super.key, this.showSplash = true});

  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'PaperFlow',
        debugShowCheckedModeBanner: false,
        theme: PaperFlowTheme.light(),
        home: _PaperFlowBootstrap(showSplash: showSplash),
      ),
    );
  }
}

class _PaperFlowBootstrap extends StatefulWidget {
  const _PaperFlowBootstrap({required this.showSplash});

  final bool showSplash;

  @override
  State<_PaperFlowBootstrap> createState() => _PaperFlowBootstrapState();
}

class _PaperFlowBootstrapState extends State<_PaperFlowBootstrap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late bool _splashComplete;

  @override
  void initState() {
    super.initState();
    _splashComplete = !widget.showSplash;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(
          CurveTween(curve: Curves.easeInCubic),
        ),
        weight: 20,
      ),
    ]).animate(_controller);
    _scale = Tween(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.showSplash) {
      _controller
        ..addStatusListener(_handleAnimationStatus)
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_splashComplete) return const PaperFlowShell();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              'assets/images/paperflow_logo.png',
              width: 112,
              height: 112,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _splashComplete = true);
    }
  }
}

class PaperFlowShell extends StatefulWidget {
  const PaperFlowShell({super.key});

  @override
  State<PaperFlowShell> createState() => _PaperFlowShellState();
}

class _PaperFlowShellState extends State<PaperFlowShell> {
  int _selectedIndex = 0;
  late final PaperController _paperController;

  @override
  void initState() {
    super.initState();
    _paperController = PaperController(const DemoPaperRepository())
      ..addListener(_handlePaperStateChanged);
  }

  @override
  void dispose() {
    _paperController
      ..removeListener(_handlePaperStateChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PaperFlowColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                PapersScreen(controller: _paperController),
                CommunityScreen(),
                MessagesScreen(),
                ProfileScreen(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: PaperFlowBottomNav(
              selectedIndex: _selectedIndex,
              papersGridMode: _paperController.gridMode,
              onSelected: _handleNavigation,
              onCreate: () => _showCreateSheet(context),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNavigation(int index) {
    if (index == 0 && _selectedIndex == 0) {
      _paperController.toggleGridMode();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _handlePaperStateChanged() {
    if (mounted) setState(() {});
  }

  void _showCreateSheet(BuildContext context) {
    showPaperFlowSheet<void>(
      context: context,
      builder: (context) => Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: PaperFlowColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '创建内容',
                style: TextStyle(
                  color: PaperFlowColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _CreateAction(
                      icon: Icons.upload_file_rounded,
                      label: '上传论文',
                      color: PaperFlowColors.primary,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CreateAction(
                      icon: Icons.edit_note_rounded,
                      label: '发布动态',
                      color: PaperFlowColors.purple,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateAction extends StatelessWidget {
  const _CreateAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: PaperFlowColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
