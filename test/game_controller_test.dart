import 'package:flutter_test/flutter_test.dart';
import 'package:whack_mole/controllers/game_controller.dart';
import 'package:whack_mole/models/mole_state.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameController Tests', () {
    late GameController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      controller = GameController();
    });

    test('Initial state is correct', () {
      expect(controller.state, GameState.home);
      expect(controller.score, 0);
      expect(controller.combo, 0);
      expect(controller.maxCombo, 0);
      expect(controller.timeLeft, GameController.gameDurationSeconds.toDouble());
      expect(controller.isFeverMode, false);
      expect(controller.moles.length, 9);
      for (var mole in controller.moles) {
        expect(mole.isUp, false);
        expect(mole.isHit, false);
      }
    });

    test('Start game changes state and resets parameters', () {
      controller.startGame();
      expect(controller.state, GameState.playing);
      expect(controller.score, 0);
      expect(controller.combo, 0);
      expect(controller.timeLeft, GameController.gameDurationSeconds.toDouble());
      controller.stopGame(); // Clean up timers
    });

    test('Pause and resume game transitions state correctly', () {
      controller.startGame();
      expect(controller.state, GameState.playing);

      controller.pauseGame();
      expect(controller.state, GameState.paused);

      controller.resumeGame();
      expect(controller.state, GameState.playing);

      controller.stopGame();
    });

    test('Whack returns null if game is not active', () {
      final outcome = controller.whack(0);
      expect(outcome, isNull);
    });

    test('Whacking active mole rewards points', () {
      controller.startGame();
      
      // Manually force a normal mole up in slot 0
      final mole = controller.moles[0];
      mole.popUp(MoleType.normal, const Duration(seconds: 2));

      final outcome = controller.whack(0);
      
      expect(outcome, isNotNull);
      expect(outcome!['success'], true);
      expect(outcome['points'], 10);
      expect(outcome['type'], MoleType.normal);
      expect(controller.score, 10);
      expect(controller.combo, 1);

      controller.stopGame();
    });

    test('Whacking spiky mole deducts points and breaks combo', () {
      controller.startGame();

      // Force a spiky mole up
      final mole = controller.moles[1];
      mole.popUp(MoleType.spiky, const Duration(seconds: 2));

      // Hitting spiky mole
      final outcome = controller.whack(1);

      expect(outcome, isNotNull);
      expect(outcome!['success'], false);
      expect(outcome['points'], -15);
      expect(controller.score, 0); // score caps at 0
      expect(controller.combo, 0);

      controller.stopGame();
    });

    test('Fever Mode triggers at 10 combo', () {
      controller.startGame();

      // Simulate 10 successful hits to trigger Fever Mode
      for (int i = 0; i < 10; i++) {
        // Find a slot and put a normal mole up, then whack it
        controller.moles[0].popUp(MoleType.normal, const Duration(seconds: 2));
        controller.whack(0);
      }

      expect(controller.combo, 10);
      expect(controller.isFeverMode, true);
      expect(controller.feverTimeLeft, 8.0);

      // Next normal whack should give double points
      controller.moles[0].popUp(MoleType.normal, const Duration(seconds: 2));
      final outcome = controller.whack(0);
      expect(outcome!['points'], 20); // 10 * 2

      controller.stopGame();
    });
  });
}
