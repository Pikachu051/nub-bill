import 'package:flutter/material.dart';

/// Wraps a child widget with a slide+fade entrance animation on first build.
/// Useful for items in a regular ListView or Column that should animate in.
class AnimatedItemWrapper extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration staggerDelay;

  const AnimatedItemWrapper({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 300),
    this.staggerDelay = const Duration(milliseconds: 50),
  });

  @override
  State<AnimatedItemWrapper> createState() => _AnimatedItemWrapperState();
}

class _AnimatedItemWrapperState extends State<AnimatedItemWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Stagger start based on index, but cap at 500ms to avoid
    // items being stuck invisible on fast navigation.
    final delay = widget.staggerDelay * widget.index;
    if (delay <= Duration.zero) {
      _controller.forward();
    } else {
      final capped = delay > const Duration(milliseconds: 500)
          ? const Duration(milliseconds: 500)
          : delay;
      Future.delayed(capped, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
