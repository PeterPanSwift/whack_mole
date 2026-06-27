import 'dart:math';
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/mole_state.dart';
import '../mole_widget.dart';

class GameOverScreen extends StatefulWidget {
  final GameController controller;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  const GameOverScreen({
    super.key,
    required this.controller,
    required this.onRestart,
    required this.onHome,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> with TickerProviderStateMixin {
  late AnimationController _cardController;
  late Animation<double> _scaleAnimation;
  late AnimationController _confettiController;
  final List<ConfettiItem> _confettis = [];
  final Random _random = Random();

  // A local mole state just for animation decoration
  final MoleState _resultMole = MoleState(id: 101, type: MoleType.normal, isUp: true);

  @override
  void initState() {
    super.initState();
    // Animating the score card pop in
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.elasticOut,
    );
    _cardController.forward();

    // Determine decoration mole type based on score
    final score = widget.controller.score;
    if (score >= 250) {
      _resultMole.type = MoleType.golden;
    } else if (score >= 120) {
      _resultMole.type = MoleType.normal;
    } else if (score >= 60) {
      _resultMole.type = MoleType.nurse;
    } else {
      _resultMole.type = MoleType.spiky;
    }

    // Trigger high score celebration (confetti) if high score beaten
    final bool isCelebration = score >= widget.controller.highScore || score >= 120;
    if (isCelebration) {
      _initConfettis();
      _confettiController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat();
      _confettiController.addListener(() {
        setState(() {
          for (var confetti in _confettis) {
            confetti.update();
          }
        });
      });
    }
  }

  void _initConfettis() {
    final List<Color> confettiColors = [
      const Color(0xFFFF8A80),
      const Color(0xFFFFD54F),
      const Color(0xFF81C784),
      const Color(0xFF4FC3F7),
      const Color(0xFFBA68C8),
    ];
    for (int i = 0; i < 40; i++) {
      _confettis.add(
        ConfettiItem(
          x: _random.nextDouble() * 400, // scaled in builder
          y: -_random.nextDouble() * 300,
          color: confettiColors[_random.nextInt(confettiColors.length)],
        ),
      );
    }
  }

  @override
  void dispose() {
    _cardController.dispose();
    if (widget.controller.score >= widget.controller.highScore || widget.controller.score >= 120) {
      _confettiController.dispose();
    }
    super.dispose();
  }

  Map<String, String> _evaluatePerformance(int score) {
    if (score >= 350) {
      return {'rank': 'SSS', 'title': '👑 究極打地鼠神 👑', 'msg': '地鼠們見到你都瑟瑟發抖！'};
    } else if (score >= 250) {
      return {'rank': 'SS', 'title': '🏆 打地鼠大師 🏆', 'msg': '手速驚人！簡直是職業選手！'};
    } else if (score >= 180) {
      return {'rank': 'S', 'title': '🌟 打地鼠高手 🌟', 'msg': '非常優秀！反應速度極快！'};
    } else if (score >= 120) {
      return {'rank': 'A', 'title': '✨ 打地鼠達人 ✨', 'msg': '很棒喔！地鼠無所遁形！'};
    } else if (score >= 60) {
      return {'rank': 'B', 'title': '🐹 打地鼠新手 🐹', 'msg': '漸入佳境！再多練習一下吧！'};
    } else {
      return {'rank': 'C', 'title': '💤 睡著的地鼠 💤', 'msg': '地鼠都在你頭上跳舞了啦～'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.controller.score;
    final maxCombo = widget.controller.maxCombo;
    final isNewRecord = score >= widget.controller.highScore && score > 0;
    final eval = _evaluatePerformance(score);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Pastel Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF3E0), // Soft orange pastel
                  Color(0xFFF3E5F5), // Light lavender
                ],
              ),
            ),
          ),

          // 2. Confetti Overlay
          if (score >= widget.controller.highScore || score >= 120)
            CustomPaint(
              painter: ConfettiPainter(confettis: _confettis),
              size: Size.infinite,
            ),

          // 3. Central Card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: min(MediaQuery.of(context).size.width - 40, 360.0),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: const Color(0xFFD7CCC8), width: 6),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          "遊戲結束",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.brown[800],
                            letterSpacing: 2.0,
                          ),
                        ),
                        
                        const Divider(height: 24, thickness: 2),

                        // Score expression mole
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: MoleWidget(
                            moleState: _resultMole,
                            onTap: () {
                              setState(() {
                                _resultMole.isHit = true;
                              });
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (mounted) setState(() => _resultMole.isHit = false);
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // New Record Badge
                        if (isNewRecord)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD54F),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Text(
                              "👑 新紀錄 👑",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ),

                        // Score
                        Text(
                          "得分",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          "$score",
                          style: const TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFEC407A), // Bubblegum pink
                          ),
                        ),

                        // Max Combo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("🔥 ", style: TextStyle(fontSize: 16)),
                            Text(
                              "最大連擊: $maxCombo",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Rank box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFDCEDC8), width: 2),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "評價: ${eval['rank']}",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF33691E),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                eval['title']!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF558B2F),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                eval['msg']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Action Buttons
                        Row(
                          children: [
                            // Home Button
                            Expanded(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: widget.onHome,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCE93D8), // Pastel Purple
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFBA68C8).withOpacity(0.4),
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "回主畫面",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Replay Button
                            Expanded(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: widget.onRestart,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF81C784), // Pastel Green
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF4CAF50).withOpacity(0.4),
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "再玩一次",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfettiItem {
  late double x;
  late double y;
  late double speedY;
  late double speedX;
  late double angle;
  late double rotationSpeed;
  late double sizeW;
  late double sizeH;
  late Color color;
  final Random _random = Random();

  ConfettiItem({required this.x, required this.y, required this.color}) {
    speedY = _random.nextDouble() * 3 + 2;
    speedX = (_random.nextDouble() - 0.5) * 2;
    angle = _random.nextDouble() * 2 * pi;
    rotationSpeed = (_random.nextDouble() - 0.5) * 0.15;
    sizeW = _random.nextDouble() * 8 + 6;
    sizeH = _random.nextDouble() * 12 + 8;
  }

  void update() {
    y += speedY;
    x += speedX;
    angle += rotationSpeed;
    if (y > 900) {
      y = -20;
      x = _random.nextDouble() * 400;
      speedY = _random.nextDouble() * 3 + 2;
    }
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiItem> confettis;

  ConfettiPainter({required this.confettis});

  @override
  void paint(Canvas canvas, Size size) {
    for (var c in confettis) {
      final double actualX = (c.x / 400) * size.width;
      final double actualY = (c.y / 800) * size.height;

      final Paint paint = Paint()
        ..color = c.color
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(actualX, actualY);
      canvas.rotate(c.angle);

      // Draw rectangular ribbon
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: c.sizeW, height: c.sizeH),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}
