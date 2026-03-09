import 'package:flutter/material.dart';

/// A tab indicator that keeps the underline at a fixed ratio of tab width.
///
/// Use [widthFactor] = 0.5 to make underline length equal to half of each tab.
class HalfWidthTabIndicator extends Decoration {
  final Color color;
  final double thickness;
  final double widthFactor;
  final double radius;

  const HalfWidthTabIndicator({
    required this.color,
    this.thickness = 2.0,
    this.widthFactor = 0.5,
    this.radius = 2.0,
  }) : assert(widthFactor > 0 && widthFactor <= 1);

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _HalfWidthTabIndicatorPainter(this, onChanged);
  }
}

class _HalfWidthTabIndicatorPainter extends BoxPainter {
  final HalfWidthTabIndicator indicator;

  _HalfWidthTabIndicatorPainter(this.indicator, super.onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;

    final indicatorWidth = size.width * indicator.widthFactor;
    if (indicatorWidth <= 0) return;

    final left = offset.dx + ((size.width - indicatorWidth) / 2);
    final top = offset.dy + size.height - indicator.thickness;
    final rect = Rect.fromLTWH(left, top, indicatorWidth, indicator.thickness);

    final paint = Paint()
      ..color = indicator.color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    if (indicator.radius > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(indicator.radius)),
        paint,
      );
      return;
    }

    canvas.drawRect(rect, paint);
  }
}
