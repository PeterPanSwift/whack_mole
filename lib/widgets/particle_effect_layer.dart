import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/mole_state.dart';
import '../models/particle.dart';

class ParticleEffectLayer extends StatefulWidget {
  const ParticleEffectLayer({super.key});

  @override
  State<ParticleEffectLayer> createState() => ParticleEffectLayerState();
}

class ParticleEffectLayerState extends State<ParticleEffectLayer> with SingleTickerProviderStateMixin {
  final List<GameParticle> _particles = [];
  late Ticker _ticker;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Ticker ticks every frame to animate particles
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      _updateParticles();
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _updateParticles() {
    if (_particles.isEmpty) return;

    setState(() {
      for (var particle in _particles) {
        particle.update();
      }
      // Remove dead particles
      _particles.removeWhere((p) => p.isDead);
    });
  }

  /// Spawn particles at a specific position
  void spawnParticles({
    required Offset position,
    required String text,
    required MoleType? type,
    required bool success,
    bool isMiss = false,
  }) {
    final List<GameParticle> newParticles = [];

    // 1. Add Floating Text Particle
    Color textColor;
    double textSize = 26.0;
    if (isMiss) {
      textColor = const Color(0xFF90A4AE); // Grey
      textSize = 22.0;
    } else {
      switch (type) {
        case MoleType.golden:
          textColor = const Color(0xFFFFD54F); // Golden Yellow
          textSize = 30.0;
          break;
        case MoleType.spiky:
          textColor = const Color(0xFFE53935); // Angry Red
          textSize = 28.0;
          break;
        case MoleType.nurse:
          textColor = const Color(0xFF66BB6A); // Green/Pink Heal
          textSize = 28.0;
          break;
        default:
          textColor = const Color(0xFFEC407A); // Cute Pink
          break;
      }
    }

    // Text Particle floats straight up and expands/fades
    newParticles.add(
      GameParticle(
        position: Offset(position.dx, position.dy - 15),
        velocity: const Offset(0, -2.5),
        color: textColor,
        size: textSize,
        decay: 0.02, // Lasts about 50 frames (approx 0.8s)
        type: ParticleType.text,
        text: text,
      ),
    );

    // 2. Add Sparkle/Burst Particles
    int count = isMiss ? 3 : 12;
    if (type == MoleType.golden) count = 18;

    for (int i = 0; i < count; i++) {
      final double angle = _random.nextDouble() * 2 * pi;
      final double speed = _random.nextDouble() * 5 + 2;
      final Offset velocity = Offset(cos(angle) * speed, sin(angle) * speed - 1.5); // shoot upwards slightly

      Color pColor;
      ParticleType pType = ParticleType.sparkle;
      double size = _random.nextDouble() * 8 + 6;

      if (isMiss) {
        pColor = const Color(0xFFCFD8DC);
        pType = ParticleType.bubble;
      } else {
        switch (type) {
          case MoleType.golden:
            pColor = i % 2 == 0 ? const Color(0xFFFFD54F) : const Color(0xFFFFEB3B);
            pType = ParticleType.star;
            size += 2;
            break;
          case MoleType.spiky:
            pColor = i % 2 == 0 ? const Color(0xFF7E57C2) : const Color(0xFF4A148C);
            pType = ParticleType.bubble;
            break;
          case MoleType.nurse:
            pColor = i % 2 == 0 ? const Color(0xFFF48FB1) : const Color(0xFF81C784);
            pType = i % 2 == 0 ? ParticleType.heart : ParticleType.star;
            break;
          default:
            // Normal Mole: mixed sweet colors
            final List<Color> sweetColors = [
              const Color(0xFFF06292), // Pink
              const Color(0xFF4FC3F7), // Blue
              const Color(0xFFFFD54F), // Yellow
              const Color(0xFF81C784), // Green
            ];
            pColor = sweetColors[_random.nextInt(sweetColors.length)];
            pType = _random.nextDouble() > 0.4 ? ParticleType.star : ParticleType.heart;
            break;
        }
      }

      newParticles.add(
        GameParticle(
          position: position,
          velocity: velocity,
          color: pColor,
          size: size,
          decay: _random.nextDouble() * 0.03 + 0.02,
          type: pType,
          angle: _random.nextDouble() * 2 * pi,
          angularVelocity: (_random.nextDouble() - 0.5) * 0.2,
        ),
      );
    }

    setState(() {
      _particles.addAll(newParticles);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: ParticlePainter(particles: _particles),
        child: Container(),
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<GameParticle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      if (p.isDead) continue;

      final double alpha = p.life;
      final Paint paint = Paint()
        ..color = p.color.withOpacity(alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.angle);

      switch (p.type) {
        case ParticleType.star:
          _drawStar(canvas, paint, p.size);
          break;
        case ParticleType.heart:
          _drawHeart(canvas, paint, p.size);
          break;
        case ParticleType.bubble:
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = 2;
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          // Shine dot
          final Paint shinePaint = Paint()..color = Colors.white.withOpacity(alpha);
          canvas.drawCircle(Offset(-p.size / 6, -p.size / 6), p.size / 10, shinePaint);
          break;
        case ParticleType.sparkle:
          _drawSparkle(canvas, paint, p.size);
          break;
        case ParticleType.text:
          // We draw the text with a cute thick black outline
          if (p.text != null) {
            _drawStrokeText(canvas, p.text!, p.size, alpha, p.color);
          }
          break;
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final Path path = Path();
    int points = 5;
    double rx = size;
    double ry = size * 0.4;
    double angle = -pi / 2;
    double add = pi / points;

    for (int i = 0; i < points * 2; i++) {
      double r = (i % 2 == 0) ? rx : ry;
      double currX = cos(angle) * r;
      double currY = sin(angle) * r;
      if (i == 0) {
        path.moveTo(currX, currY);
      } else {
        path.lineTo(currX, currY);
      }
      angle += add;
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, Paint paint, double size) {
    final Path path = Path();
    final double width = size * 1.2;
    final double height = size * 1.2;

    path.moveTo(0, -height / 4);
    // Left curve
    path.cubicTo(-width / 2, -height * 0.7, -width, 0, 0, height / 2);
    // Right curve
    path.cubicTo(width, 0, width / 2, -height * 0.7, 0, -height / 4);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawSparkle(Canvas canvas, Paint paint, double size) {
    // 4-point cute sparkle star
    final Path path = Path();
    path.moveTo(0, -size);
    path.quadraticBezierTo(0, 0, size, 0);
    path.quadraticBezierTo(0, 0, 0, size);
    path.quadraticBezierTo(0, 0, -size, 0);
    path.quadraticBezierTo(0, 0, 0, -size);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawStrokeText(Canvas canvas, String text, double size, double alpha, Color color) {
    // 1. Text Painter for the background stroke (black outline)
    final textSpanStroke = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        fontFamily: 'Courier', // cute monospace look, or fall back to system
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.black.withOpacity(alpha),
      ),
    );

    final textPainterStroke = TextPainter(
      text: textSpanStroke,
      textDirection: TextDirection.ltr,
    );
    textPainterStroke.layout();

    // 2. Text Painter for the foreground text
    final textSpanFill = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        fontFamily: 'Courier',
        color: color.withOpacity(alpha),
      ),
    );

    final textPainterFill = TextPainter(
      text: textSpanFill,
      textDirection: TextDirection.ltr,
    );
    textPainterFill.layout();

    // Center text at coordinate (0, 0)
    final Offset textOffset = Offset(-textPainterFill.width / 2, -textPainterFill.height / 2);
    
    textPainterStroke.paint(canvas, textOffset);
    textPainterFill.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return true; // Always repaint because particles animate every frame
  }
}
