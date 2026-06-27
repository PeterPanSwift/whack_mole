import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../mole_widget.dart';
import '../../models/mole_state.dart';

class HomeScreen extends StatefulWidget {
  final GameController controller;

  const HomeScreen({
    super.key,
    required this.controller,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _bubbleController;
  final List<FloatingBubble> _bubbles = List.generate(15, (_) => FloatingBubble());

  // A local mole state just for decoration on home screen
  final MoleState _demoMole1 = MoleState(id: 99, type: MoleType.normal, isUp: true);
  final MoleState _demoMole2 = MoleState(id: 100, type: MoleType.golden, isUp: true);
  late Timer _demoTimer;

  @override
  void initState() {
    super.initState();
    // Bouncing logo animation
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOutSine),
    );

    // Floating background bubbles animation
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _bubbleController.addListener(() {
      setState(() {
        for (var bubble in _bubbles) {
          bubble.move();
        }
      });
    });

    // Make demo moles pop up and down periodically on home screen
    _demoTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        _demoMole1.isUp = !_demoMole1.isUp;
        _demoMole2.isUp = !_demoMole2.isUp;
        if (_demoMole1.isUp) {
          _demoMole1.type = Random().nextBool() ? MoleType.normal : MoleType.nurse;
        }
        if (_demoMole2.isUp) {
          _demoMole2.type = Random().nextBool() ? MoleType.golden : MoleType.spiky;
        }
      });
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _bubbleController.dispose();
    _demoTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Pastel Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8F5E9), // Light mint green
                  Color(0xFFF3E5F5), // Light lavender/pink
                ],
              ),
            ),
          ),

          // 2. Floating Background Bubbles
          CustomPaint(
            painter: BubblePainter(bubbles: _bubbles),
            size: Size.infinite,
          ),

          // 3. Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Bouncing Logo Container
                    AnimatedBuilder(
                      animation: _bounceAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _bounceAnimation.value),
                          child: child,
                        );
                      },
                      child: _buildLogo(),
                    ),

                    const SizedBox(height: 40),

                    // High Score Badge
                    _buildHighScoreBadge(),

                    const SizedBox(height: 50),

                    // Floating Demo Moles Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: MoleWidget(
                            moleState: _demoMole1,
                            onTap: () {
                              setState(() {
                                _demoMole1.isHit = true;
                              });
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (mounted) setState(() => _demoMole1.isHit = false);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 80),
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: MoleWidget(
                            moleState: _demoMole2,
                            onTap: () {
                              setState(() {
                                _demoMole2.isHit = true;
                              });
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (mounted) setState(() => _demoMole2.isHit = false);
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 50),

                    // Start Game Button
                    _buildStartButton(),

                    const SizedBox(height: 40),

                    // Cute footer text
                    Text(
                      "點擊地鼠即可得分！避開帶刺地鼠喔～",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[600],
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Shadow / Outline backdrop
          Text(
            "可愛打地鼠",
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 10
                ..color = const Color(0xFF4E342E), // Dark brown
            ),
          ),
          // Filled text
          const Text(
            "可愛打地鼠",
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFF8A80), // Cute salmon pink
              letterSpacing: 4.0,
              shadows: [
                Shadow(
                  offset: Offset(0, 4),
                  blurRadius: 0,
                  color: Color(0xFFBCAAA4),
                )
              ],
            ),
          ),
          // A tiny cute crown decoration on the title
          Positioned(
            top: -24,
            left: 20,
            child: Transform.rotate(
              angle: -0.2,
              child: const Icon(
                Icons.star,
                color: Color(0xFFFFD54F),
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighScoreBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD7CCC8), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events,
            color: Color(0xFFFFB300),
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            "最高得分: ${widget.controller.highScore}",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF5D4037),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          widget.controller.startGame();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFF81C784), // Cute soft green
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(0.4),
                blurRadius: 0,
                offset: const Offset(0, 6), // 3D look
              ),
            ],
          ),
          child: const Text(
            "開始遊戲",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingBubble {
  late double x;
  late double y;
  late double radius;
  late double speed;
  late Color color;
  final Random _random = Random();

  FloatingBubble() {
    x = _random.nextDouble() * 400; // will be scaled dynamically
    y = _random.nextDouble() * 800;
    radius = _random.nextDouble() * 30 + 15;
    speed = _random.nextDouble() * 0.4 + 0.2;
    
    final List<Color> bubbleColors = [
      const Color(0xFFFFCDD2).withOpacity(0.35), // soft red
      const Color(0xFFE1BEE7).withOpacity(0.35), // soft purple
      const Color(0xFFC8E6C9).withOpacity(0.35), // soft green
      const Color(0xFFB3E5FC).withOpacity(0.35), // soft blue
    ];
    color = bubbleColors[_random.nextInt(bubbleColors.length)];
  }

  void move() {
    y -= speed;
    if (y < -radius * 2) {
      y = 900; // Reset to bottom
      x = _random.nextDouble() * 500;
    }
  }
}

class BubblePainter extends CustomPainter {
  final List<FloatingBubble> bubbles;

  BubblePainter({required this.bubbles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var bubble in bubbles) {
      // Map bubble x position to current screen width
      final double actualX = (bubble.x / 400) * size.width;
      final double actualY = (bubble.y / 800) * size.height;

      final Paint paint = Paint()
        ..color = bubble.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(actualX, actualY), bubble.radius, paint);
      
      // Highlight dot
      final Paint highlightPaint = Paint()..color = Colors.white.withOpacity(bubble.color.opacity * 0.8);
      canvas.drawCircle(Offset(actualX - bubble.radius / 3, actualY - bubble.radius / 3), bubble.radius / 5, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
