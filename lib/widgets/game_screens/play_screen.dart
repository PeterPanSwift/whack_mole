import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../controllers/game_controller.dart';
import '../../models/mole_state.dart';
import '../mole_widget.dart';
import '../particle_effect_layer.dart';
import '../hammer_widget.dart';

class PlayScreen extends StatefulWidget {
  final GameController controller;
  final VoidCallback onPausePressed;

  const PlayScreen({
    super.key,
    required this.controller,
    required this.onPausePressed,
  });

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ParticleEffectLayerState> _particleKey =
      GlobalKey<ParticleEffectLayerState>();
  final GlobalKey<HammerWidgetState> _hammerKey =
      GlobalKey<HammerWidgetState>();
  final GlobalKey _stackKey = GlobalKey();

  // Screen shake state
  double _shakeOffset = 0.0;
  Timer? _shakeTimer;

  // add two numbers

  @override
  void initState() {
    super.initState();
    // Add controller listener to trigger shake on angry hits
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _shakeTimer?.cancel();
    super.dispose();
  }

  void _onControllerChange() {
    // If the controller reports a change, we check if we need to rebuild.
    // In our case, the state of the controller is reflected by widget.controller.
    if (mounted) {
      setState(() {});
    }
  }

  void _triggerScreenShake() {
    _shakeTimer?.cancel();
    int ticks = 0;
    const int maxTicks = 10;
    const double maxOffset = 8.0;

    _shakeTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (ticks >= maxTicks) {
          _shakeOffset = 0.0;
          timer.cancel();
        } else {
          // Alternating shake offset
          _shakeOffset =
              (ticks % 2 == 0 ? 1 : -1) * maxOffset * (1 - ticks / maxTicks);
          ticks++;
        }
      });
    });
  }

  void _handleTapHole(int index, TapDownDetails details) {
    if (widget.controller.state != GameState.playing) return;

    // Convert global coordinate of tap to local coordinate of the main Stack
    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final Offset localPos = stackBox.globalToLocal(details.globalPosition);

    // 1. Play Hammer Animation
    _hammerKey.currentState?.swingAt(localPos);

    // 2. Trigger Game Controller Whack
    final outcome = widget.controller.whack(index);
    if (outcome != null) {
      final bool success = outcome['success'];
      final String text = outcome['text'];
      final MoleType? type = outcome['type'];

      // 3. Play screen shake if hit a spiky mole
      if (type == MoleType.spiky) {
        _triggerScreenShake();
      }

      // 4. Trigger Particle effects
      _particleKey.currentState?.spawnParticles(
        position: localPos,
        text: text,
        type: type,
        success: success,
      );
    }
  }

  void _handleBackgroundTap(TapDownDetails details) {
    // Handled when user taps outside the mole grid (e.g. missed completely)
    if (widget.controller.state != GameState.playing) return;

    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final Offset localPos = stackBox.globalToLocal(details.globalPosition);

    // Play hammer swing
    _hammerKey.currentState?.swingAt(localPos);

    // Whack index -1 representing total miss
    final outcome = widget.controller.whack(-1);
    if (outcome != null) {
      _particleKey.currentState?.spawnParticles(
        position: localPos,
        text: outcome['text'],
        type: null,
        success: false,
        isMiss: true,
      );
    }
  }

  Widget _buildHUD(BuildContext context) {
    final controller = widget.controller;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Score Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD54F), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text("⭐ ", style: TextStyle(fontSize: 18)),
                Text(
                  "得分: ${controller.score}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 15),

          // Custom animated Progress Bar
          Expanded(child: _buildTimeProgressBar()),

          const SizedBox(width: 15),

          // Pause Button
          GestureDetector(
            onTap: widget.onPausePressed,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE0E0E0), width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.pause,
                color: Color(0xFFEC407A),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeProgressBar() {
    final double progress =
        (widget.controller.timeLeft / GameController.gameDurationSeconds).clamp(
          0.0,
          1.0,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double barWidth = constraints.maxWidth;
        // Calculate mole runner position along the progress bar
        final double runnerPos =
            barWidth * progress - 16; // Adjust offset to center runner image

        return Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            // Bar background track
            Container(
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 2.5),
              ),
            ),
            // Progress fill
            Container(
              height: 18,
              width: barWidth * progress,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF81C784), // mint light green
                    Color(0xFF4CAF50), // green
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            // Running cute mole head at the front of the progress bar
            Positioned(
              left: max(0.0, runnerPos),
              top: -8,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF8D5B4C), // mole brown
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text("🐹", style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComboBadge() {
    final controller = widget.controller;
    if (controller.combo == 0)
      return const SizedBox(height: 48); // Fixed height to prevent layout jump

    // Fever Mode visual enhancements
    final double comboScale = 1.0 + min(0.4, controller.combo * 0.03);
    final Color comboColor = controller.isFeverMode
        ? const Color(0xFFFF4081)
        : const Color(0xFFAB47BC);

    return Transform.scale(
      scale: comboScale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: comboColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: comboColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          controller.isFeverMode
              ? "🔥 FEVER COMBO x${controller.combo} 🔥"
              : "COMBO x${controller.combo}",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  // Rewriting the grid item to catch TapDownDetails
  Widget _buildGridBoardItem(int index) {
    final mole = widget.controller.moles[index];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) => _handleTapHole(index, details),
      child: MoleWidget(
        moleState: mole,
        onTap: () {
          // Handled via onTapDown above
        },
      ),
    );
  }

  // Overriding buildGridBoard to use our GestureDetector wrappers
  Widget _buildGridBoardCustom(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    final double boardSize = min(min(width - 32, height * 0.6), 420.0);

    return Container(
      width: boardSize,
      height: boardSize,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFC2B280), // Cute sand/soil texture background
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF8D6E63), width: 6),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          return _buildGridBoardItem(index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final Color boardBg = controller.isFeverMode
        ? const Color(0xFFFFF3E0) // Warm fever pastel orange
        : const Color(0xFFE8F5E9); // Mint green normal

    return Scaffold(
      body: Stack(
        key: _stackKey,
        children: [
          // 1. Ground/Grass Background (tappable to trigger mallet misses)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleBackgroundTap,
            child: Container(color: boardBg),
          ),

          // 2. Fever Mode Rainbow Border Pulse
          if (controller.isFeverMode) const FeverBorderPulse(),

          // 3. Game Layout
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildHUD(context),

                const Spacer(),

                // Combo Badge
                _buildComboBadge(),

                const SizedBox(height: 10),

                // Whacking Board with Screen Shake Translation
                Transform.translate(
                  offset: Offset(_shakeOffset, 0),
                  child: Center(child: _buildGridBoardCustom(context)),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),

          // 4. Particle Effects Overlay (Pass-through taps)
          ParticleEffectLayer(key: _particleKey),

          // 5. Mallet Animation Overlay (Pass-through taps)
          HammerWidget(key: _hammerKey),
        ],
      ),
    );
  }
}

class FeverBorderPulse extends StatefulWidget {
  const FeverBorderPulse({super.key});

  @override
  State<FeverBorderPulse> createState() => _FeverBorderPulseState();
}

class _FeverBorderPulseState extends State<FeverBorderPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _borderController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xFFFF8A80).withOpacity(0.3),
      end: const Color(0xFFFFD54F).withOpacity(0.3),
    ).animate(_borderController);
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _colorAnimation.value ?? Colors.red,
                width: 12,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_colorAnimation.value ?? Colors.red).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
