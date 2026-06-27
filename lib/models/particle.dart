import 'package:flutter/material.dart';

enum ParticleType {
  star,
  heart,
  bubble,
  sparkle,
  text,
}

class GameParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life; // 1.0 (spawn) to 0.0 (death)
  double decay; // How fast life decreases
  ParticleType type;
  String? text;
  double angle;
  double angularVelocity;

  GameParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    this.life = 1.0,
    required this.decay,
    required this.type,
    this.text,
    this.angle = 0.0,
    this.angularVelocity = 0.0,
  });

  void update() {
    position += velocity;
    velocity = Offset(velocity.dx * 0.98, velocity.dy + 0.15); // Add air resistance and light gravity
    life = (life - decay).clamp(0.0, 1.0);
    angle += angularVelocity;
  }

  bool get isDead => life <= 0.0;
}
