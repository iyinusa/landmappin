import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Custom animated location marker widget
class CustomLocationMarker {
  /// Creates a custom animated user location marker
  static Future<BitmapDescriptor> createAnimatedLocationMarker({
    double size = 110.0,
    Color primaryColor = Colors.blue,
    Color pulseColor = Colors.lightBlue,
    bool withPulse = true,
    bool withAccuracyCircle = true,
    double accuracy = 10.0,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint();

    final center = Offset(size / 2, size / 2);
    final radius = size / 4;

    // Draw accuracy circle (outer transparent circle)
    if (withAccuracyCircle) {
      paint
        ..color = primaryColor.withOpacity(0.1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, size / 2 - 2, paint);

      paint
        ..color = primaryColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, size / 2 - 2, paint);
    }

    // Draw pulsing ring
    if (withPulse) {
      paint
        ..color = pulseColor.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(center, radius + 8, paint);

      paint
        ..color = pulseColor.withOpacity(0.2)
        ..strokeWidth = 6.0;
      canvas.drawCircle(center, radius + 12, paint);
    }

    // Draw main location dot with shadow
    // Shadow
    paint
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center + const Offset(1, 1), radius + 2, paint);

    // Outer ring
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 2, paint);

    // Inner dot
    paint
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    // Inner highlight
    paint
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center - const Offset(2, 2), radius / 3, paint);

    // Direction indicator (small arrow)
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    arrowPath.moveTo(center.dx, center.dy - radius / 2);
    arrowPath.lineTo(center.dx - 3, center.dy + 2);
    arrowPath.lineTo(center.dx + 3, center.dy + 2);
    arrowPath.close();
    canvas.drawPath(arrowPath, arrowPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Creates a custom marker for navigation destination
  static Future<BitmapDescriptor> createDestinationMarker({
    double size = 45.0,
    Color color = Colors.red,
    String? label,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint();

    final markerHeight = size;
    final markerWidth = size * 0.7;
    final centerX = markerWidth / 2;

    // Draw marker shadow
    paint
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final shadowPath = Path();
    shadowPath.moveTo(centerX + 1, markerHeight - 5 + 1);
    shadowPath.lineTo(centerX - markerWidth / 3 + 1, markerHeight / 3 + 1);
    shadowPath.quadraticBezierTo(
        centerX + 1, 1, centerX + markerWidth / 3 + 1, markerHeight / 3 + 1);
    shadowPath.close();
    canvas.drawPath(shadowPath, paint);

    // Draw main marker
    paint
      ..color = color
      ..style = PaintingStyle.fill;

    final markerPath = Path();
    markerPath.moveTo(centerX, markerHeight - 5);
    markerPath.lineTo(centerX - markerWidth / 3, markerHeight / 3);
    markerPath.quadraticBezierTo(
        centerX, 0, centerX + markerWidth / 3, markerHeight / 3);
    markerPath.close();
    canvas.drawPath(markerPath, paint);

    // Draw white circle inside
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(centerX, markerHeight / 3), markerWidth / 6, paint);

    // Draw inner dot
    paint
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(centerX, markerHeight / 3), markerWidth / 12, paint);

    final picture = pictureRecorder.endRecording();
    final image =
        await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Creates a custom marker for map points
  static Future<BitmapDescriptor> createPointMarker({
    double size = 45.0,
    Color color = Colors.red,
    IconData icon = Icons.location_on_outlined,
    String? label,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    final markerHeight = size;
    final markerWidth = size * 0.8;
    final centerX = markerWidth / 2;

    // Draw marker with gradient
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.9),
          color.withOpacity(1.0),
          color.withOpacity(0.8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, markerWidth, markerHeight));

    final markerPath = Path();
    markerPath.moveTo(centerX, markerHeight);
    markerPath.lineTo(centerX - markerWidth / 3, markerHeight * 0.6);
    markerPath.quadraticBezierTo(centerX, markerHeight * 0.2,
        centerX + markerWidth / 3, markerHeight * 0.6);
    markerPath.close();
    canvas.drawPath(markerPath, paint);

    // Draw white circle
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(centerX, markerHeight * 0.6), markerWidth / 6, whitePaint);

    // Draw icon (simplified as a circle for now)
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(centerX, markerHeight * 0.6), markerWidth / 12, iconPaint);

    final picture = pictureRecorder.endRecording();
    final image =
        await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Creates a pulsing location marker for real-time tracking
  static Widget createPulsingLocationWidget({
    double size = 110.0,
    Color color = Colors.blue,
  }) {
    return AnimatedLocationPulse(size: size, color: color);
  }

  /// Creates a larger animated location marker for better visibility
  static Future<BitmapDescriptor> createLargeAnimatedLocationMarker({
    double size = 150.0,
    Color primaryColor = Colors.blue,
    Color pulseColor = Colors.lightBlue,
    bool withPulse = true,
    bool withAccuracyCircle = true,
    double accuracy = 10.0,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint();

    final center = Offset(size / 2, size / 2);
    final radius = size / 3; // Larger radius for better visibility

    // Draw accuracy circle (outer transparent circle)
    if (withAccuracyCircle) {
      paint
        ..color = primaryColor.withOpacity(0.1)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, size / 2 - 2, paint);

      paint
        ..color = primaryColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0; // Thicker stroke
      canvas.drawCircle(center, size / 2 - 2, paint);
    }

    // Draw pulsing ring with more prominent effect
    if (withPulse) {
      paint
        ..color = pulseColor.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(center, radius + 12, paint);

      paint
        ..color = pulseColor.withOpacity(0.3)
        ..strokeWidth = 8.0;
      canvas.drawCircle(center, radius + 18, paint);
    }

    // Draw main location dot with enhanced shadow
    // Shadow
    paint
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center + const Offset(2, 2), radius + 3, paint);

    // Outer ring
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 3, paint);

    // Inner dot
    paint
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    // Inner highlight
    paint
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center - const Offset(3, 3), radius / 2.5, paint);

    // Direction indicator (larger arrow)
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    arrowPath.moveTo(center.dx, center.dy - radius / 1.5);
    arrowPath.lineTo(center.dx - 5, center.dy + 4);
    arrowPath.lineTo(center.dx + 5, center.dy + 4);
    arrowPath.close();
    canvas.drawPath(arrowPath, arrowPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}

/// Animated pulsing location widget for overlays
class AnimatedLocationPulse extends StatefulWidget {
  final double size;
  final Color color;

  const AnimatedLocationPulse({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  State<AnimatedLocationPulse> createState() => _AnimatedLocationPulseState();
}

class _AnimatedLocationPulseState extends State<AnimatedLocationPulse>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Rotation animation
    _rotateController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.linear,
    ));

    // Start animations
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 3,
      height: widget.size * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing outer ring
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: widget.size * _pulseAnimation.value,
                height: widget.size * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(0.3),
                ),
              );
            },
          ),

          // Second pulsing ring
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: widget.size * (_pulseAnimation.value * 0.7),
                height: widget.size * (_pulseAnimation.value * 0.7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(0.5),
                ),
              );
            },
          ),

          // Rotating outer ring
          AnimatedBuilder(
            animation: _rotateAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnimation.value * 2 * 3.14159,
                child: Container(
                  width: widget.size * 1.5,
                  height: widget.size * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withOpacity(0.6),
                      width: 2,
                    ),
                  ),
                  child: CustomPaint(
                    painter: DirectionIndicatorPainter(color: widget.color),
                  ),
                ),
              );
            },
          ),

          // Static center dot
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
              child: const Icon(
                Icons.navigation,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for direction indicator
class DirectionIndicatorPainter extends CustomPainter {
  final Color color;

  DirectionIndicatorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 4;

    // Draw small direction dots
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * (3.14159 / 180);
      final x = center.dx + radius * 0.8 * math.cos(angle);
      final y = center.dy + radius * 0.8 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
