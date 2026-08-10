import 'package:flutter/material.dart';
import '../../../../core/theme/spark_design_tokens.dart';
import '../../../../core/theme/spark_font_sizes.dart';

class ChatSessionSwipeAction extends StatefulWidget {
  const ChatSessionSwipeAction({
    super.key,
    required this.sessionId,
    required this.revealed,
    required this.pinned,
    required this.onReveal,
    required this.onClose,
    required this.onTogglePinned,
    required this.onDelete,
    required this.child,
    this.borderRadius =
        const BorderRadius.all(Radius.circular(SparkDesignTokens.radius2Xl)),
  });

  final String sessionId;
  final bool revealed;
  final bool pinned;
  final VoidCallback onReveal;
  final VoidCallback onClose;
  final VoidCallback onTogglePinned;
  final VoidCallback onDelete;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<ChatSessionSwipeAction> createState() => _ChatSessionSwipeActionState();
}

class _ChatSessionSwipeActionState extends State<ChatSessionSwipeAction> {
  static const _actionWidth = 72.0;
  static const _actionsExtent = _actionWidth * 2;

  double _dragOffset = 0;
  bool _dragging = false;

  double get _targetOffset {
    if (_dragging) return _dragOffset;
    return widget.revealed ? -_actionsExtent : 0;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: ClipRRect(
                key: ValueKey('ai-session-actions-${widget.sessionId}'),
                borderRadius: widget.borderRadius,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SwipeActionButton(
                      key: ValueKey('ai-session-pin-${widget.sessionId}'),
                      width: _actionWidth,
                      icon: widget.pinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin_rounded,
                      label: widget.pinned ? '取消置顶' : '置顶',
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                      onTap: () {
                        widget.onClose();
                        widget.onTogglePinned();
                      },
                    ),
                    _SwipeActionButton(
                      key: ValueKey('ai-session-delete-${widget.sessionId}'),
                      width: _actionWidth,
                      icon: Icons.delete_outline_rounded,
                      label: '删除',
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onErrorContainer,
                      onTap: () {
                        widget.onClose();
                        widget.onDelete();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedContainer(
            key: ValueKey('ai-session-swipe-${widget.sessionId}'),
            duration:
                _dragging ? Duration.zero : const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_targetOffset, 0, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.revealed ? widget.onClose : null,
              onHorizontalDragStart: _startDrag,
              onHorizontalDragUpdate: _updateDrag,
              onHorizontalDragEnd: _endDrag,
              child: AbsorbPointer(
                absorbing: widget.revealed,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startDrag(DragStartDetails details) {
    setState(() {
      _dragging = true;
      _dragOffset = widget.revealed ? -_actionsExtent : 0;
    });
  }

  void _updateDrag(DragUpdateDetails details) {
    setState(() {
      _dragOffset =
          (_dragOffset + details.delta.dx).clamp(-_actionsExtent, 0).toDouble();
    });
  }

  void _endDrag(DragEndDetails details) {
    final reveal =
        details.primaryVelocity != null && details.primaryVelocity! < -420 ||
            _dragOffset <= -_actionsExtent * 0.38;
    setState(() => _dragging = false);
    if (reveal) {
      widget.onReveal();
    } else {
      widget.onClose();
    }
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    super.key,
    required this.width,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: double.infinity,
      child: Material(
        color: backgroundColor,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 21),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: SparkFontSizes.caption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
