import 'package:flutter/material.dart';

/// Swipe a row to the left to reveal a single trailing action button (e.g. a
/// bin). Tapping the button fires [onAction]; the row snaps shut once the
/// action's future resolves. Swiping back — or tapping the still-open row —
/// closes it without firing.
///
/// Generic on purpose: it owns the gesture + reveal animation and nothing
/// about deletion. The destructive wiring lives in the caller.
class SwipeToReveal extends StatefulWidget {
  final Widget child;
  final IconData actionIcon;
  final Color actionBackgroundColor;
  final Color actionForegroundColor;
  final String actionSemanticLabel;
  final Future<void> Function() onAction;

  /// Width of the revealed action area.
  final double actionExtent;

  const SwipeToReveal({
    super.key,
    required this.child,
    required this.actionIcon,
    required this.actionBackgroundColor,
    required this.actionForegroundColor,
    required this.actionSemanticLabel,
    required this.onAction,
    this.actionExtent = 88,
  });

  @override
  State<SwipeToReveal> createState() => _SwipeToRevealState();
}

class _SwipeToRevealState extends State<SwipeToReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  bool get _isOpen => _controller.value > 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() => _controller.animateTo(1, curve: Curves.easeOut);
  void _close() => _controller.animateTo(0, curve: Curves.easeOut);

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = -details.primaryDelta! / widget.actionExtent;
    _controller.value = (_controller.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity < -300) {
      _open();
    } else if (velocity > 300) {
      _close();
    } else {
      _controller.value > 0.5 ? _open() : _close();
    }
  }

  Future<void> _handleAction() async {
    await widget.onAction();
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          // Trailing action sits behind the row, revealed as it slides left.
          Positioned.fill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Semantics(
                  button: true,
                  label: widget.actionSemanticLabel,
                  child: Material(
                    color: widget.actionBackgroundColor,
                    child: InkWell(
                      onTap: _handleAction,
                      child: SizedBox(
                        width: widget.actionExtent,
                        child: Center(
                          child: Icon(
                            widget.actionIcon,
                            color: widget.actionForegroundColor,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(-widget.actionExtent * _controller.value, 0),
              child: child,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // While open, intercept taps on the row to close it instead of
                // letting them fall through to the child's own tap handler.
                return Stack(
                  children: [
                    child!,
                    if (_isOpen)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _close,
                        ),
                      ),
                  ],
                );
              },
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
