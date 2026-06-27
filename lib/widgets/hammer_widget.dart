import 'dart:math';
import 'package:flutter/material.dart';

class HammerWidget extends StatefulWidget {
  const HammerWidget({super.key});

  @override
  State<HammerWidget> createState() => HammerWidgetState();
}

class HammerWidgetState extends State<HammerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _swingAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Swing goes from -45 degrees (tilted back) to 15 degrees (impact)
    _swingAnimation = Tween<double>(begin: -pi / 4, end: pi / 10).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInBack, // Wind up and strike!
      ),
    );

    // Fade out at the end of the swing
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_animController);

    // Scale pop-in and squash slightly
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 1.1), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.8), weight: 40),
    ]).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Trigger hammer swing at position
  void swingAt(Offset position) {
    setState(() {
      _tapPosition = position;
    });
    _animController.reset();
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_tapPosition == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final double opacity = _opacityAnimation.value;
          if (opacity <= 0.0) return const SizedBox.shrink();

          return Positioned(
            left: _tapPosition!.dx - 80, // Offset so the mallet head aligns with hit point
            top: _tapPosition!.dy - 90,  // Offset vertically
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                // Pivot point for hammer swing is the bottom of the handle
                origin: const Offset(80, 90), 
                child: Transform.rotate(
                  angle: _swingAnimation.value,
                  origin: const Offset(80, 90), // pivot around handle base
                  child: CustomPaint(
                    size: const Size(120, 110),
                    painter: HammerPainter(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class HammerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Handle is a diagonal line from bottom-right (pivot) to center-left
    final Offset handleStart = Offset(w * 0.85, h * 0.85); // Pivot area
    final Offset handleEnd = Offset(w * 0.35, h * 0.35);  // Hammer head join

    // Paint for handle
    final Paint handlePaint = Paint()
      ..color = const Color(0xFFF7DC6F) // Cute yellow pastel handle
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(handleStart, handleEnd, handlePaint);

    // Cute wooden grip lines
    final Paint gripPaint = Paint()
      ..color = const Color(0xFFD4AC0D)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      handleStart - Offset(5, 5),
      handleStart - Offset(20, 20),
      gripPaint,
    );

    // Mallet Head (barrel shape)
    // Centered around handleEnd, rotated perpendicular to the handle angle
    final double handleAngle = atan2(handleEnd.dy - handleStart.dy, handleEnd.dx - handleStart.dx);
    final double perpendicularAngle = handleAngle + pi / 2;

    // Move to join position
    canvas.save();
    canvas.translate(handleEnd.dx, handleEnd.dy);
    canvas.rotate(perpendicularAngle);

    // Draw cute wooden barrel
    final double headW = 34.0;
    final double headH = 58.0;

    final Paint headPaint = Paint()
      ..color = const Color(0xFFE59866) // Soft pastel wood brown
      ..style = PaintingStyle.fill;
    
    // Draw barrel body
    final RRect barrelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: headW, height: headH),
      const Radius.circular(8),
    );
    canvas.drawRRect(barrelRect, headPaint);

    // Decorative pink rubber cushions on ends
    final Paint rubberPaint = Paint()
      ..color = const Color(0xFFF1948A) // Soft red-pink
      ..style = PaintingStyle.fill;
    
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, -headH / 2), width: headW * 1.1, height: 10),
      rubberPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, headH / 2), width: headW * 1.1, height: 10),
      rubberPaint,
    );

    // Shiny highlights on the barrel wood
    final Paint woodHighlight = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(-headW / 4, -headH / 3, -headW / 12, headH / 3),
      woodHighlight,
    );

    canvas.restore();

    // Draw a small "impact" sparkle when fully swung down
    // (Visual representation of striking force)
    final Paint impactPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(handleEnd - const Offset(15, 10), 4, impactPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
