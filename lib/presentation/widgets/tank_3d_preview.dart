import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Minimal isometric preview of the rectangular tank with its water level.
///
/// Proportions follow the entered dimensions; the water prism animates
/// whenever the measured water height changes.
class Tank3DPreview extends StatelessWidget {
  final double widthCm;
  final double lengthCm;
  final double heightCm;
  final double? waterHeightCm;
  final bool showLabels;
  final double padding;

  /// Fixed height; null fills the parent's constraints.
  final double? height;

  const Tank3DPreview({
    super.key,
    required this.widthCm,
    required this.lengthCm,
    required this.heightCm,
    this.waterHeightCm,
    this.showLabels = true,
    this.padding = 28,
    this.height = 190,
  });

  bool get _isValid => widthCm > 0 && lengthCm > 0 && heightCm > 0;

  @override
  Widget build(BuildContext context) {
    final fraction = _isValid && waterHeightCm != null
        ? (waterHeightCm! / heightCm).clamp(0.0, 1.0)
        : 0.0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, animatedFraction, _) => CustomPaint(
          painter: _TankPainter(
            width: _isValid ? widthCm : 1,
            length: _isValid ? lengthCm : 1,
            height: _isValid ? heightCm : 1,
            waterFraction: animatedFraction,
            showLabels: showLabels && _isValid,
            padding: padding,
            labelStyle: AppTextStyles.chartLabel.copyWith(fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _TankPainter extends CustomPainter {
  final double width;
  final double length;
  final double height;
  final double waterFraction;
  final bool showLabels;
  final double padding;
  final TextStyle labelStyle;

  _TankPainter({
    required this.width,
    required this.length,
    required this.height,
    required this.waterFraction,
    required this.showLabels,
    required this.padding,
    required this.labelStyle,
  });

  static final double _cos30 = math.cos(math.pi / 6);
  static const double _sin30 = 0.5;

  /// Isometric projection: x = width, y = length, z = height (up).
  Offset _project(double x, double y, double z) =>
      Offset((x - y) * _cos30, (x + y) * _sin30 - z);

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the projected box inside the canvas with some padding for labels.
    final corners = [
      for (final x in [0.0, width])
        for (final y in [0.0, length])
          for (final z in [0.0, height]) _project(x, y, z),
    ];
    final minX = corners.map((p) => p.dx).reduce(math.min);
    final maxX = corners.map((p) => p.dx).reduce(math.max);
    final minY = corners.map((p) => p.dy).reduce(math.min);
    final maxY = corners.map((p) => p.dy).reduce(math.max);

    final scale = math.min(
      (size.width - padding * 2) / (maxX - minX),
      (size.height - padding * 2) / (maxY - minY),
    );
    final offset = Offset(
      (size.width - (maxX - minX) * scale) / 2 - minX * scale,
      (size.height - (maxY - minY) * scale) / 2 - minY * scale,
    );
    Offset p(double x, double y, double z) => _project(x, y, z) * scale + offset;

    // ── Water prism (visible faces only: front-left, front-right, top) ──
    final w = height * waterFraction;
    if (w > 0) {
      final water = AppColors.humedadTeal;
      _fillFace(canvas, [p(0, length, 0), p(width, length, 0), p(width, length, w), p(0, length, w)],
          water.withValues(alpha: 0.35));
      _fillFace(canvas, [p(width, 0, 0), p(width, length, 0), p(width, length, w), p(width, 0, w)],
          water.withValues(alpha: 0.22));
      _fillFace(canvas, [p(0, 0, w), p(width, 0, w), p(width, length, w), p(0, length, w)],
          water.withValues(alpha: 0.5));
    }

    // ── Tank edges ──
    final hidden = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.18)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final visible = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.75)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Edges meeting at the hidden back-bottom corner (0,0,0).
    canvas.drawLine(p(0, 0, 0), p(width, 0, 0), hidden);
    canvas.drawLine(p(0, 0, 0), p(0, length, 0), hidden);
    canvas.drawLine(p(0, 0, 0), p(0, 0, height), hidden);

    // Visible edges.
    final edges = [
      [p(width, 0, 0), p(width, length, 0)],
      [p(0, length, 0), p(width, length, 0)],
      [p(width, 0, 0), p(width, 0, height)],
      [p(0, length, 0), p(0, length, height)],
      [p(width, length, 0), p(width, length, height)],
      [p(0, 0, height), p(width, 0, height)],
      [p(0, 0, height), p(0, length, height)],
      [p(width, 0, height), p(width, length, height)],
      [p(0, length, height), p(width, length, height)],
    ];
    for (final e in edges) {
      canvas.drawLine(e[0], e[1], visible);
    }

    // ── Dimension labels ──
    if (showLabels) {
      // Anchored outwards from each edge so labels never overlap.
      _label(canvas, 'Ancho ${_fmt(width)}', (p(0, length, 0) + p(width, length, 0)) / 2 + const Offset(-6, 8),
          anchor: const Offset(1, 0));
      _label(canvas, 'Largo ${_fmt(length)}', (p(width, 0, 0) + p(width, length, 0)) / 2 + const Offset(6, 8),
          anchor: const Offset(0, 0));
      _label(canvas, 'Alto ${_fmt(height)}', (p(0, length, 0) + p(0, length, height)) / 2 + const Offset(-8, 0),
          anchor: const Offset(1, 0.5));
    }
  }

  void _fillFace(Canvas canvas, List<Offset> points, Color color) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  /// Paints [text] so that [anchor] (0..1 fraction of the label box) sits at [position].
  void _label(Canvas canvas, String text, Offset position, {required Offset anchor}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, position - Offset(painter.width * anchor.dx, painter.height * anchor.dy));
  }

  String _fmt(double v) =>
      '${v == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(1)} cm';

  @override
  bool shouldRepaint(covariant _TankPainter old) =>
      old.width != width ||
      old.length != length ||
      old.height != height ||
      old.waterFraction != waterFraction ||
      old.showLabels != showLabels ||
      old.padding != padding;
}
