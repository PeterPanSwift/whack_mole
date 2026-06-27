import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mole_state.dart';

class MoleImageCache {
  static final Map<MoleType, ui.Image> images = {};
  static bool loaded = false;

  static Future<void> loadImages() async {
    if (loaded) return;
    try {
      images[MoleType.normal] = await _loadImage('assets/images/mole_normal.png');
      images[MoleType.golden] = await _loadImage('assets/images/mole_golden.png');
      images[MoleType.spiky] = await _loadImage('assets/images/mole_spiky.png');
      images[MoleType.nurse] = await _loadImage('assets/images/mole_nurse.png');
      loaded = true;
    } catch (e) {
      debugPrint("Failed to load mole images: $e");
      // Fallback to vector moles by marking loaded as true
      loaded = true;
    }
  }

  static Future<ui.Image> _loadImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }
}

class MoleWidget extends StatefulWidget {
  final MoleState moleState;
  final VoidCallback onTap;

  const MoleWidget({
    super.key,
    required this.moleState,
    required this.onTap,
  });

  @override
  State<MoleWidget> createState() => _MoleWidgetState();
}

class _MoleWidgetState extends State<MoleWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _popAnimation;
  bool _localHit = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Standard slide up transition
    _popAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInQuad,
    );

    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant MoleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.moleState.isUp) {
      if (!_animController.isAnimating && _animController.value < 1.0) {
        _animController.forward();
      }
    } else {
      if (!_animController.isAnimating && _animController.value > 0.0) {
        _animController.reverse();
      }
    }

    if (widget.moleState.isHit && !_localHit) {
      setState(() {
        _localHit = true;
      });
      // Trigger a quick hit squash-and-shake animation
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _localHit = false;
          });
        }
      });
    } else if (!widget.moleState.isHit && _localHit) {
      setState(() {
        _localHit = false;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _popAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: MolePainter(
              popProgress: _popAnimation.value,
              type: widget.moleState.type,
              isHit: widget.moleState.isHit,
              isLocalHitActive: _localHit,
            ),
          );
        },
      ),
    );
  }
}

class MolePainter extends CustomPainter {
  final double popProgress;
  final MoleType type;
  final bool isHit;
  final bool isLocalHitActive;

  MolePainter({
    required this.popProgress,
    required this.type,
    required this.isHit,
    required this.isLocalHitActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Hole center parameters
    final double holeCenterX = w / 2;
    final double holeCenterY = h * 0.78;
    final double holeRx = w * 0.42;
    final double holeRy = h * 0.16;

    // 1. Draw Hole Background (Shadow/Inside)
    final Paint holeBgPaint = Paint()
      ..color = const Color(0xFF3E2723) // Deep soil brown
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(holeCenterX, holeCenterY),
        width: holeRx * 2,
        height: holeRy * 2,
      ),
      holeBgPaint,
    );

    // Inner dark depth shadow
    final Paint holeDepthPaint = Paint()
      ..color = const Color(0xFF1E100C)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(holeCenterX, holeCenterY + 4),
        width: holeRx * 1.8,
        height: holeRy * 1.5,
      ),
      holeDepthPaint,
    );

    // 2. Draw the Mole
    // We clip the mole so it doesn't render below the hole
    canvas.save();
    
    // Create clip path for the surface. We only allow rendering ABOVE the bottom of the hole rim.
    final Path clipPath = Path()
      ..addRect(Rect.fromLTRB(0, 0, w, holeCenterY + holeRy * 0.3));
    canvas.clipPath(clipPath);

    if (popProgress > 0) {
      _paintMole(canvas, w, h, holeCenterX, holeCenterY);
    }
    
    canvas.restore();

    // 3. Draw Hole Foreground (Front Rim + Grass details)
    final Paint holeRimPaint = Paint()
      ..color = const Color(0xFF5D4037) // Lighter soil brown
      ..style = PaintingStyle.fill;

    // We draw the front half of the ellipse rim
    final Path frontRimPath = Path()
      ..addArc(
        Rect.fromCenter(
          center: Offset(holeCenterX, holeCenterY),
          width: holeRx * 2,
          height: holeRy * 2,
        ),
        0, // starts at 3 o'clock
        pi, // goes clockwise to 9 o'clock
      )
      ..quadraticBezierTo(holeCenterX - holeRx * 0.8, holeCenterY + holeRy * 1.1, holeCenterX, holeCenterY + holeRy * 1.2)
      ..quadraticBezierTo(holeCenterX + holeRx * 0.8, holeCenterY + holeRy * 1.1, holeCenterX + holeRx, holeCenterY);
    canvas.drawPath(frontRimPath, holeRimPaint);

    // Add some cute grass details or clods around the hole
    final Paint grassPaint = Paint()
      ..color = const Color(0xFF81C784) // Soft cute green
      ..style = PaintingStyle.fill;

    // Grass patch Left
    final Path grassL = Path()
      ..moveTo(holeCenterX - holeRx * 0.9, holeCenterY + 4)
      ..lineTo(holeCenterX - holeRx * 1.1, holeCenterY - 12)
      ..lineTo(holeCenterX - holeRx * 0.8, holeCenterY - 4)
      ..lineTo(holeCenterX - holeRx * 0.7, holeCenterY - 15)
      ..lineTo(holeCenterX - holeRx * 0.6, holeCenterY)
      ..close();
    canvas.drawPath(grassL, grassPaint);

    // Grass patch Right
    final Path grassR = Path()
      ..moveTo(holeCenterX + holeRx * 0.9, holeCenterY + 4)
      ..lineTo(holeCenterX + holeRx * 1.1, holeCenterY - 12)
      ..lineTo(holeCenterX + holeRx * 0.8, holeCenterY - 4)
      ..lineTo(holeCenterX + holeRx * 0.7, holeCenterY - 15)
      ..lineTo(holeCenterX + holeRx * 0.6, holeCenterY)
      ..close();
    canvas.drawPath(grassR, grassPaint);
  }

  void _paintMole(Canvas canvas, double w, double h, double centerX, double centerY) {
    final ui.Image? image = MoleImageCache.images[type];
    if (image != null) {
      // Y positioning: popProgress goes from 0.0 (hidden) to 1.0 (fully up)
      final double moleHeight = h * 0.46;
      final double moleWidth = w * 0.44;
      final double targetY = centerY - moleHeight * 0.8;
      final double hiddenY = centerY + moleHeight * 0.2;
      double currentY = hiddenY - (hiddenY - targetY) * popProgress;

      // Apply squash and stretch animations
      double scaleX = 1.0;
      double scaleY = 1.0;

      if (isLocalHitActive) {
        // Squash when whacked
        scaleX = 1.25;
        scaleY = 0.75;
        currentY += moleHeight * 0.12; // lower Y to match squash
      } else {
        // Stretch on rising, settle at top
        if (popProgress < 0.8) {
          scaleX = 0.92;
          scaleY = 1.12;
        } else if (popProgress < 1.0) {
          final double bounce = (popProgress - 0.8) / 0.2;
          scaleX = 0.92 + 0.12 * bounce;
          scaleY = 1.12 - 0.16 * bounce;
        }
      }

      canvas.save();
      // Translate to center bottom of the mole for scaling
      canvas.translate(centerX, centerY);
      canvas.scale(scaleX, scaleY);
      // Translate back relative to center bottom
      canvas.translate(-centerX, -centerY);

      // Draw the AI image sticker
      final double badgeSize = moleWidth * 1.15; // slightly larger for details
      final Rect dstRect = Rect.fromCenter(
        center: Offset(centerX, currentY + badgeSize / 2),
        width: badgeSize,
        height: badgeSize,
      );

      // Clip to circular badge shape
      final Path circleClip = Path()
        ..addOval(dstRect);
      
      canvas.save();
      canvas.clipPath(circleClip);

      final Rect srcRect = Rect.fromLTRB(0, 0, image.width.toDouble(), image.height.toDouble());
      
      // If hit, we can add a visual filter (e.g. grayscale or slight tint)
      final Paint imagePaint = Paint()..filterQuality = ui.FilterQuality.high;
      if (isHit) {
        // Apply a dizzy grey/blue tint
        imagePaint.colorFilter = const ColorFilter.mode(
          Colors.grey,
          BlendMode.color,
        );
      }
      
      canvas.drawImageRect(image, srcRect, dstRect, imagePaint);
      canvas.restore();
      canvas.restore();

      // Draw dizzy stars above head if hit
      if (isHit) {
        _drawDizzyStars(canvas, centerX, currentY, moleWidth);
      }
    } else {
      // Fallback to vector mole
      _paintVectorMole(canvas, w, h, centerX, centerY);
    }
  }

  void _paintVectorMole(Canvas canvas, double w, double h, double centerX, double centerY) {
    // Mole configuration based on type
    Color bodyColor;
    Color bellyColor = const Color(0xFFFCE4EC); // Cute light pink belly
    
    switch (type) {
      case MoleType.normal:
        bodyColor = const Color(0xFF8D5B4C); // Classic cute brown
        break;
      case MoleType.golden:
        bodyColor = const Color(0xFFFBC02D); // Vibrant gold
        bellyColor = const Color(0xFFFFF9C4); // Creamy yellow
        break;
      case MoleType.spiky:
        bodyColor = const Color(0xFF6A1B9A); // Dark purple-grey
        bellyColor = const Color(0xFFE1BEE7); // Soft light purple
        break;
      case MoleType.nurse:
        bodyColor = const Color(0xFFEC407A); // Cute pink
        bellyColor = const Color(0xFFFCE4EC); // White pink
        break;
    }

    // Y positioning: popProgress goes from 0.0 (hidden) to 1.0 (fully up)
    // Hidden Y: centerY + moleHeight
    // Fully popped Y: centerY - moleHeight
    final double moleHeight = h * 0.46;
    final double moleWidth = w * 0.44;
    
    // Normal vertical offset for mole top center
    final double targetY = centerY - moleHeight * 0.8;
    final double hiddenY = centerY + moleHeight * 0.2;
    double currentY = hiddenY - (hiddenY - targetY) * popProgress;

    // Apply squash and stretch animations
    double scaleX = 1.0;
    double scaleY = 1.0;

    if (isLocalHitActive) {
      // Squash when whacked
      scaleX = 1.25;
      scaleY = 0.75;
      currentY += moleHeight * 0.12; // lower Y to match squash
    } else {
      // Stretch on rising, settle at top
      if (popProgress < 0.8) {
        scaleX = 0.92;
        scaleY = 1.12;
      } else if (popProgress < 1.0) {
        // slight bounce/settle
        final double bounce = (popProgress - 0.8) / 0.2; // 0 to 1
        scaleX = 0.92 + 0.12 * bounce;
        scaleY = 1.12 - 0.16 * bounce;
      }
    }

    canvas.save();
    // Translate to center bottom of the mole for scaling
    canvas.translate(centerX, centerY);
    canvas.scale(scaleX, scaleY);
    // Translate back relative to center bottom
    canvas.translate(-centerX, -centerY);

    // Draw Mole Body (Rounded Rect or pill path)
    final Paint bodyPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    final double moleTop = currentY;
    final double moleBottom = centerY + moleHeight * 0.1;
    final double moleLeft = centerX - moleWidth / 2;
    final double moleRight = centerX + moleWidth / 2;

    final RRect bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(moleLeft, moleTop, moleRight, moleBottom),
      topLeft: Radius.circular(moleWidth * 0.5),
      topRight: Radius.circular(moleWidth * 0.5),
      bottomLeft: Radius.circular(moleWidth * 0.2),
      bottomRight: Radius.circular(moleWidth * 0.2),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Draw Belly Patch
    final Paint bellyPaint = Paint()
      ..color = bellyColor
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, moleTop + moleHeight * 0.65),
        width: moleWidth * 0.7,
        height: moleHeight * 0.4,
      ),
      bellyPaint,
    );

    // Draw Face details: Eyes, Blush, Nose, Mouth
    final double eyeY = moleTop + moleHeight * 0.32;
    final double eyeSpacing = moleWidth * 0.22;
    final double noseY = moleTop + moleHeight * 0.40;
    
    // 1. Blush (always cute!)
    final Paint blushPaint = Paint()
      ..color = const Color(0xFFFF8A80).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX - eyeSpacing * 1.3, eyeY + 8), width: 14, height: 8),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX + eyeSpacing * 1.3, eyeY + 8), width: 14, height: 8),
      blushPaint,
    );

    // 2. Eyes
    final Paint eyePaint = Paint()
      ..color = const Color(0xFF212121)
      ..style = PaintingStyle.fill;

    if (isHit) {
      // Dizzy X eyes
      final Paint xPaint = Paint()
        ..color = const Color(0xFF212121)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Left Eye X
      canvas.drawLine(Offset(centerX - eyeSpacing - 5, eyeY - 5), Offset(centerX - eyeSpacing + 5, eyeY + 5), xPaint);
      canvas.drawLine(Offset(centerX - eyeSpacing - 5, eyeY + 5), Offset(centerX - eyeSpacing + 5, eyeY - 5), xPaint);
      // Right Eye X
      canvas.drawLine(Offset(centerX + eyeSpacing - 5, eyeY - 5), Offset(centerX + eyeSpacing + 5, eyeY + 5), xPaint);
      canvas.drawLine(Offset(centerX + eyeSpacing - 5, eyeY + 5), Offset(centerX + eyeSpacing + 5, eyeY - 5), xPaint);
    } else {
      switch (type) {
        case MoleType.spiky:
          // Angry eyes (diagonal lines or angled arches)
          final Paint angryPaint = Paint()
            ..color = const Color(0xFF212121)
            ..strokeWidth = 3.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          // Left Eye \
          canvas.drawLine(Offset(centerX - eyeSpacing - 6, eyeY - 3), Offset(centerX - eyeSpacing + 6, eyeY + 3), angryPaint);
          // Right Eye /
          canvas.drawLine(Offset(centerX + eyeSpacing + 6, eyeY - 3), Offset(centerX + eyeSpacing - 6, eyeY + 3), angryPaint);
          
          // Draw angry eyebrows
          final Paint browPaint = Paint()
            ..color = const Color(0xFF311B92)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(centerX - eyeSpacing - 8, eyeY - 10), Offset(centerX - eyeSpacing + 2, eyeY - 7), browPaint);
          canvas.drawLine(Offset(centerX + eyeSpacing + 8, eyeY - 10), Offset(centerX + eyeSpacing - 2, eyeY - 7), browPaint);
          break;

        case MoleType.nurse:
          // Sweet curved winking / sleeping eyes (^^)
          final Paint curvePaint = Paint()
            ..color = const Color(0xFF212121)
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
          
          final Path eyePathL = Path()
            ..moveTo(centerX - eyeSpacing - 6, eyeY + 2)
            ..quadraticBezierTo(centerX - eyeSpacing, eyeY - 4, centerX - eyeSpacing + 6, eyeY + 2);
          final Path eyePathR = Path()
            ..moveTo(centerX + eyeSpacing - 6, eyeY + 2)
            ..quadraticBezierTo(centerX + eyeSpacing, eyeY - 4, centerX + eyeSpacing + 6, eyeY + 2);
          
          canvas.drawPath(eyePathL, curvePaint);
          canvas.drawPath(eyePathR, curvePaint);
          break;

        case MoleType.golden:
          // Starry shiny eyes!
          _drawStarEye(canvas, Offset(centerX - eyeSpacing, eyeY), 7);
          _drawStarEye(canvas, Offset(centerX + eyeSpacing, eyeY), 7);
          break;

        case MoleType.normal:
          // Normal beads with high-glimmer dots
          canvas.drawOval(Rect.fromCenter(center: Offset(centerX - eyeSpacing, eyeY), width: 9, height: 12), eyePaint);
          canvas.drawOval(Rect.fromCenter(center: Offset(centerX + eyeSpacing, eyeY), width: 9, height: 12), eyePaint);
          
          // Glimmer
          final Paint glimmerPaint = Paint()..color = Colors.white;
          canvas.drawCircle(Offset(centerX - eyeSpacing - 2, eyeY - 3), 2, glimmerPaint);
          canvas.drawCircle(Offset(centerX + eyeSpacing - 2, eyeY - 3), 2, glimmerPaint);
          break;
      }
    }

    // 3. Nose
    final Paint nosePaint = Paint()
      ..color = type == MoleType.golden ? const Color(0xFFE65100) : const Color(0xFFE57373)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, noseY), width: 12, height: 8),
      nosePaint,
    );

    // 4. Mouth / Whiskers
    final Paint mouthPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    if (isHit) {
      // Small crying circle mouth or flat line
      canvas.drawCircle(Offset(centerX, noseY + 9), 4, mouthPaint);
    } else {
      // W-shaped cute mouth
      final Path mouthPath = Path()
        ..moveTo(centerX - 4, noseY + 5)
        ..quadraticBezierTo(centerX - 2, noseY + 9, centerX, noseY + 6)
        ..quadraticBezierTo(centerX + 2, noseY + 9, centerX + 4, noseY + 5);
      canvas.drawPath(mouthPath, mouthPaint);
    }

    // 5. Special Accessories based on MoleType
    _drawAccessories(canvas, centerX, moleTop, moleWidth, moleHeight);

    canvas.restore();

    // 6. Dizzy Stars if hit
    if (isHit) {
      _drawDizzyStars(canvas, centerX, moleTop, moleWidth);
    }
  }

  void _drawStarEye(Canvas canvas, Offset center, double size) {
    final Paint starPaint = Paint()
      ..color = const Color(0xFFE65100)
      ..style = PaintingStyle.fill;
    final Path path = Path();
    int points = 5;
    double rx = size;
    double ry = size / 2.2;
    double angle = -pi / 2;
    double add = pi / points;

    for (int i = 0; i < points * 2; i++) {
      double r = (i % 2 == 0) ? rx : ry;
      double currX = center.dx + cos(angle) * r;
      double currY = center.dy + sin(angle) * r;
      if (i == 0) {
        path.moveTo(currX, currY);
      } else {
        path.lineTo(currX, currY);
      }
      angle += add;
    }
    path.close();
    canvas.drawPath(path, starPaint);

    // Shiny white speck
    canvas.drawCircle(Offset(center.dx - 1, center.dy - 1), 1.5, Paint()..color = Colors.white);
  }

  void _drawAccessories(Canvas canvas, double centerX, double moleTop, double moleWidth, double moleHeight) {
    switch (type) {
      case MoleType.golden:
        // A cute tiny crown floating on its head
        final Paint crownPaint = Paint()
          ..color = const Color(0xFFFFD54F) // Bright golden crown
          ..style = PaintingStyle.fill;
        final Paint gemPaint = Paint()
          ..color = Colors.redAccent
          ..style = PaintingStyle.fill;

        final double crownW = moleWidth * 0.45;
        final double crownH = moleHeight * 0.18;
        final double crownY = moleTop - crownH * 0.3;

        final Path crownPath = Path()
          ..moveTo(centerX - crownW / 2, crownY + crownH)
          ..lineTo(centerX - crownW / 2, crownY + crownH * 0.2) // left tip
          ..lineTo(centerX - crownW / 4, crownY + crownH * 0.6)
          ..lineTo(centerX, crownY) // center high tip
          ..lineTo(centerX + crownW / 4, crownY + crownH * 0.6)
          ..lineTo(centerX + crownW / 2, crownY + crownH * 0.2) // right tip
          ..lineTo(centerX + crownW / 2, crownY + crownH)
          ..close();

        canvas.drawPath(crownPath, crownPaint);

        // Gems on peaks
        canvas.drawCircle(Offset(centerX - crownW / 2, crownY + crownH * 0.2), 3, gemPaint);
        canvas.drawCircle(Offset(centerX, crownY), 3, gemPaint);
        canvas.drawCircle(Offset(centerX + crownW / 2, crownY + crownH * 0.2), 3, gemPaint);
        
        // Base rim
        final Paint rimPaint = Paint()
          ..color = const Color(0xFFFFB300)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(centerX - crownW / 2, crownY + crownH), Offset(centerX + crownW / 2, crownY + crownH), rimPaint);
        break;

      case MoleType.nurse:
        // A nurse cap with a red cross
        final Paint capPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        final Paint crossPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;

        final double capW = moleWidth * 0.55;
        final double capH = moleHeight * 0.16;
        final double capY = moleTop - capH * 0.1;

        final Path capPath = Path()
          ..moveTo(centerX - capW / 2, capY + capH)
          ..quadraticBezierTo(centerX - capW / 2, capY, centerX - capW / 4, capY)
          ..lineTo(centerX + capW / 4, capY)
          ..quadraticBezierTo(centerX + capW / 2, capY, centerX + capW / 2, capY + capH)
          ..quadraticBezierTo(centerX, capY + capH * 0.7, centerX - capW / 2, capY + capH)
          ..close();

        canvas.drawPath(capPath, capPaint);

        // Draw cross
        final double crossSz = capH * 0.4;
        canvas.drawRect(Rect.fromCenter(center: Offset(centerX, capY + capH * 0.45), width: crossSz, height: crossSz * 0.3), crossPaint);
        canvas.drawRect(Rect.fromCenter(center: Offset(centerX, capY + capH * 0.45), width: crossSz * 0.3, height: crossSz), crossPaint);

        // Dark cap outline
        final Paint capOutline = Paint()
          ..color = const Color(0xFFD81B60)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawPath(capPath, capOutline);
        break;

      case MoleType.spiky:
        // Spiked gray/metallic helmet
        final Paint helmPaint = Paint()
          ..color = const Color(0xFF78909C)
          ..style = PaintingStyle.fill;
        final Paint spikePaint = Paint()
          ..color = const Color(0xFFFFB300)
          ..style = PaintingStyle.fill;

        final double helmW = moleWidth * 0.7;
        final double helmH = moleHeight * 0.22;
        final double helmY = moleTop - helmH * 0.1;

        // Helmet dome
        final Path helmPath = Path()
          ..moveTo(centerX - helmW / 2, helmY + helmH)
          ..quadraticBezierTo(centerX - helmW * 0.4, helmY, centerX, helmY)
          ..quadraticBezierTo(centerX + helmW * 0.4, helmY, centerX + helmW / 2, helmY + helmH)
          ..close();
        canvas.drawPath(helmPath, helmPaint);

        // Spikes on top (3 spikes)
        // Center spike
        final Path spikeC = Path()
          ..moveTo(centerX - 5, helmY)
          ..lineTo(centerX, helmY - 14)
          ..lineTo(centerX + 5, helmY)
          ..close();
        canvas.drawPath(spikeC, spikePaint);

        // Left spike
        final Path spikeL = Path()
          ..moveTo(centerX - helmW * 0.3 - 3, helmY + helmH * 0.3)
          ..lineTo(centerX - helmW * 0.35, helmY - 6)
          ..lineTo(centerX - helmW * 0.25, helmY + helmH * 0.1)
          ..close();
        canvas.drawPath(spikeL, spikePaint);

        // Right spike
        final Path spikeR = Path()
          ..moveTo(centerX + helmW * 0.3 + 3, helmY + helmH * 0.3)
          ..lineTo(centerX + helmW * 0.35, helmY - 6)
          ..lineTo(centerX + helmW * 0.25, helmY + helmH * 0.1)
          ..close();
        canvas.drawPath(spikeR, spikePaint);

        // Metallic highlights
        final Paint highlightPaint = Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(centerX - helmW * 0.2, helmY + helmH * 0.4), width: helmW * 0.2, height: 5),
          highlightPaint,
        );
        break;

      default:
        break;
    }
  }

  void _drawDizzyStars(Canvas canvas, double centerX, double moleTop, double moleWidth) {
    final Paint starPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;

    // We draw 3 tiny stars rotating/orbiting above the head
    final double radiusX = moleWidth * 0.35;
    final double radiusY = 6;
    final double starCenterY = moleTop - 12;

    // Use current time to make the stars spin dynamically
    final double time = DateTime.now().millisecondsSinceEpoch / 250.0;

    for (int i = 0; i < 3; i++) {
      double angle = time + (i * 2 * pi / 3);
      double sx = centerX + cos(angle) * radiusX;
      double sy = starCenterY + sin(angle) * radiusY;

      // Draw simple 4-point star for simplicity and cute speed
      final Path path = Path()
        ..moveTo(sx, sy - 5)
        ..quadraticBezierTo(sx, sy, sx + 5, sy)
        ..quadraticBezierTo(sx, sy, sx, sy + 5)
        ..quadraticBezierTo(sx, sy, sx - 5, sy)
        ..quadraticBezierTo(sx, sy, sx, sy - 5)
        ..close();
      canvas.drawPath(path, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant MolePainter oldDelegate) {
    return oldDelegate.popProgress != popProgress ||
        oldDelegate.type != type ||
        oldDelegate.isHit != isHit ||
        oldDelegate.isLocalHitActive != isLocalHitActive ||
        isHit; // Always repaint when hit so dizzy stars animate!
  }
}
