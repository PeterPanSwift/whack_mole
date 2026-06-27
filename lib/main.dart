import 'dart:ui';
import 'package:flutter/material.dart';
import 'controllers/game_controller.dart';
import 'widgets/game_screens/home_screen.dart';
import 'widgets/game_screens/play_screen.dart';
import 'widgets/game_screens/game_over_screen.dart';
import 'widgets/mole_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp())
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '可愛打地鼠 App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Pastel primary color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEC407A), // Bubblegum Pink
          primary: const Color(0xFFEC407A),
          secondary: const Color(0xFF81C784), // Mint Green
          background: const Color(0xFFF3E5F5), // Lavender background
        ),
        // Rounded custom button themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
      home: const GameCoordinator(),
    );
  }
}

class GameCoordinator extends StatefulWidget {
  const GameCoordinator({super.key});

  @override
  State<GameCoordinator> createState() => _GameCoordinatorState();
}

class _GameCoordinatorState extends State<GameCoordinator> {
  late GameController _controller;
  bool _imagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller = GameController();
    _controller.addListener(_onStateChange);
    
    // Load AI-drawn mole images on startup
    MoleImageCache.loadImages().then((_) {
      if (mounted) {
        setState(() {
          _imagesLoaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFFF3E5F5), // Lavender background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC407A)), // Pink loader
              strokeWidth: 5,
            ),
            SizedBox(height: 24),
            Text(
              "正在喚醒地鼠們...",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF5D4037),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_imagesLoaded) {
      return _buildLoadingScreen();
    }

    Widget activeScreen;
    
    switch (_controller.state) {
      case GameState.home:
        activeScreen = HomeScreen(controller: _controller);
        break;
      case GameState.playing:
      case GameState.paused:
        // Render PlayScreen, but if paused, draw Pause Overlay on top of it
        activeScreen = Stack(
          children: [
            PlayScreen(
              controller: _controller,
              onPausePressed: () {
                _controller.pauseGame();
              },
            ),
            if (_controller.state == GameState.paused) _buildPauseOverlay(),
          ],
        );
        break;
      case GameState.gameOver:
        activeScreen = GameOverScreen(
          controller: _controller,
          onRestart: () {
            _controller.startGame();
          },
          onHome: () {
            _controller.stopGame();
          },
        );
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: activeScreen,
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Blur background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),
          
          // Pause Panel
          Center(
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation(1.0),
                curve: Curves.easeOutBack,
              ),
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFD7CCC8), width: 5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pause Title
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("🐹 ", style: TextStyle(fontSize: 22)),
                        Text(
                          "遊戲暫停",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "地鼠們正在休息，準備好就點擊繼續！",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    // Resume button
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          _controller.resumeGame();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF81C784), // Pastel Green
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "繼續遊戲",
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
                    const SizedBox(height: 12),

                    // Quit/Home button
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          _controller.stopGame();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8A80), // Pastel Coral Red
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE57373).withOpacity(0.3),
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "回主選單",
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
