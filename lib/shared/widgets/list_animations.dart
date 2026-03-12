import 'package:flutter/material.dart';

/// Standard animation durations for list item transitions.
const kListInsertDuration = Duration(milliseconds: 300);
const kListRemoveDuration = Duration(milliseconds: 200);
const kListStaggerDelay = Duration(milliseconds: 60);

/// Slide + Fade in from bottom (default for list items).
Widget slideInBuilder(
  BuildContext context,
  Widget child,
  Animation<double> animation,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

/// Fade + Shrink out (default for removed items).
Widget slideOutBuilder(
  BuildContext context,
  Widget child,
  Animation<double> animation,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
    child: SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeIn),
      axisAlignment: -1.0,
      child: child,
    ),
  );
}

/// Scale + Fade in (for card-style items).
Widget scaleInBuilder(
  BuildContext context,
  Widget child,
  Animation<double> animation,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      ),
      child: child,
    ),
  );
}

/// Scale + Fade out (for card-style removal).
Widget scaleOutBuilder(
  BuildContext context,
  Widget child,
  Animation<double> animation,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
    child: ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeIn),
      ),
      child: child,
    ),
  );
}

/// A widget that briefly highlights (pulses background color) to indicate
/// an in-place update, then fades back to transparent.
class UpdateHighlight extends StatefulWidget {
  final Widget child;
  final bool highlight;
  final Color highlightColor;
  final Duration duration;

  const UpdateHighlight({
    super.key,
    required this.child,
    this.highlight = false,
    this.highlightColor = const Color(0x1A81CEF2),
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<UpdateHighlight> createState() => _UpdateHighlightState();
}

class _UpdateHighlightState extends State<UpdateHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _colorAnimation = ColorTween(
      begin: widget.highlightColor,
      end: Colors.transparent,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.highlight) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(UpdateHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !oldWidget.highlight) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Container(
          color: _colorAnimation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
