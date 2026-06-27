import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mole_state.dart';

enum GameState {
  home,
  playing,
  paused,
  gameOver,
}

class GameController extends ChangeNotifier {
  static const int gridCount = 9;
  static const int gameDurationSeconds = 30;

  GameState _state = GameState.home;
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  double _timeLeft = gameDurationSeconds.toDouble(); // Double to allow smooth sub-second updates
  int _highScore = 0;
  bool _isFeverMode = false;
  double _feverTimeLeft = 0.0;

  final List<MoleState> _moles = List.generate(
    gridCount,
    (index) => MoleState(id: index),
  );

  Timer? _gameTimer;
  final Random _random = Random();
  SharedPreferences? _prefs;

  // Getters
  GameState get state => _state;
  int get score => _score;
  int get combo => _combo;
  int get maxCombo => _maxCombo;
  double get timeLeft => _timeLeft;
  int get highScore => _highScore;
  bool get isFeverMode => _isFeverMode;
  double get feverTimeLeft => _feverTimeLeft;
  List<MoleState> get moles => _moles;

  GameController() {
    _initHighScore();
  }

  Future<void> _initHighScore() async {
    _prefs = await SharedPreferences.getInstance();
    _highScore = _prefs?.getInt('high_score') ?? 0;
    notifyListeners();
  }

  Future<void> _saveHighScore() async {
    if (_score > _highScore) {
      _highScore = _score;
      await _prefs?.setInt('high_score', _highScore);
      notifyListeners();
    }
  }

  void startGame() {
    _state = GameState.playing;
    _score = 0;
    _combo = 0;
    _maxCombo = 0;
    _timeLeft = gameDurationSeconds.toDouble();
    _isFeverMode = false;
    _feverTimeLeft = 0.0;

    for (var mole in _moles) {
      mole.retreat();
    }

    _gameTimer?.cancel();
    // Tick every 100 milliseconds
    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), _onGameTick);
    notifyListeners();
  }

  void pauseGame() {
    if (_state == GameState.playing) {
      _state = GameState.paused;
      _gameTimer?.cancel();
      notifyListeners();
    }
  }

  void resumeGame() {
    if (_state == GameState.paused) {
      _state = GameState.playing;
      _gameTimer = Timer.periodic(const Duration(milliseconds: 100), _onGameTick);
      notifyListeners();
    }
  }

  void stopGame() {
    _state = GameState.home;
    _gameTimer?.cancel();
    for (var mole in _moles) {
      mole.retreat();
    }
    notifyListeners();
  }

  void _onGameTick(Timer timer) {
    if (_state != GameState.playing) return;

    // 1. Decrement time
    _timeLeft -= 0.1;
    if (_timeLeft <= 0) {
      _timeLeft = 0;
      _endGame();
      return;
    }

    // 2. Handle Fever Mode timer
    if (_isFeverMode) {
      _feverTimeLeft -= 0.1;
      if (_feverTimeLeft <= 0) {
        _isFeverMode = false;
        _feverTimeLeft = 0;
      }
    }

    // 3. Update existing moles and check retreat
    bool changed = false;
    for (var mole in _moles) {
      if (mole.isUp && mole.shouldRetreat()) {
        mole.retreat();
        changed = true;
      }
    }

    // 4. Try spawning moles
    if (_trySpawnMoles()) {
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _endGame() {
    _state = GameState.gameOver;
    _gameTimer?.cancel();
    for (var mole in _moles) {
      mole.retreat();
    }
    _saveHighScore();
    notifyListeners();
  }

  bool _trySpawnMoles() {
    // Current count of active moles
    int activeCount = _moles.where((m) => m.isUp).length;

    // Max moles allowed on screen simultaneously depends on difficulty (timeLeft & score) and Fever Mode
    int maxMoles = 2;
    if (_isFeverMode) {
      maxMoles = 5;
    } else {
      // Progressively allow more moles
      if (_timeLeft < 10) {
        maxMoles = 4;
      } else if (_timeLeft < 20 || _score > 150) {
        maxMoles = 3;
      }
    }

    if (activeCount >= maxMoles) return false;

    // Spawn probability per tick (100ms)
    // E.g., 20% base chance to attempt spawning if under limit
    double spawnProbability = _isFeverMode ? 0.4 : 0.2;
    if (_random.nextDouble() > spawnProbability) return false;

    // Find available holes
    List<int> emptyHoleIndices = [];
    for (int i = 0; i < gridCount; i++) {
      if (!_moles[i].isUp) {
        emptyHoleIndices.add(i);
      }
    }

    if (emptyHoleIndices.isEmpty) return false;

    // Pick a random available hole
    int targetIndex = emptyHoleIndices[_random.nextInt(emptyHoleIndices.length)];

    // Determine mole type weights
    // normal: 65%, golden: 15%, spiky: 12%, nurse: 8%
    double roll = _random.nextDouble();
    MoleType spawnedType;
    if (roll < 0.65) {
      spawnedType = MoleType.normal;
    } else if (roll < 0.80) {
      spawnedType = MoleType.golden;
    } else if (roll < 0.92) {
      spawnedType = MoleType.spiky;
    } else {
      spawnedType = MoleType.nurse;
    }

    // Determine how long the mole stays up
    // Fever mode: very fast!
    // Normal mode: base stays 1.8s, gets faster as time runs out
    double baseSeconds = 1.8;
    if (_isFeverMode) {
      baseSeconds = spawnedType == MoleType.golden ? 0.7 : 1.0;
    } else {
      // Scale down to minimum of 0.8 seconds
      double timeFactor = (_timeLeft / gameDurationSeconds).clamp(0.0, 1.0);
      baseSeconds = 0.8 + 1.0 * timeFactor;
      if (spawnedType == MoleType.golden) {
        baseSeconds *= 0.6; // Gold moles are 40% faster
      }
    }

    // Angry spikes stay longer to act as obstacles
    if (spawnedType == MoleType.spiky) {
      baseSeconds *= 1.2;
    }

    Duration moleDuration = Duration(milliseconds: (baseSeconds * 1000).toInt());
    _moles[targetIndex].popUp(spawnedType, moleDuration);
    return true;
  }

  /// Whack a mole at index
  /// Returns a Map containing outcome details (for particle rendering)
  /// Or null if it was a miss
  Map<String, dynamic>? whack(int index) {
    if (_state != GameState.playing) return null;

    MoleState mole = _moles[index];

    if (mole.isUp && !mole.isHit) {
      mole.hit();
      int pointsEarned = 0;
      bool isGoodHit = true;
      String effectText = "";

      switch (mole.type) {
        case MoleType.normal:
          pointsEarned = 10;
          _combo++;
          effectText = "+10";
          break;
        case MoleType.golden:
          pointsEarned = 30;
          _combo += 2; // Golden bonus
          effectText = "GOLD! +30";
          break;
        case MoleType.spiky:
          pointsEarned = -15;
          _combo = 0; // Break combo!
          isGoodHit = false;
          effectText = "OUCH! -15";
          break;
        case MoleType.nurse:
          pointsEarned = 10;
          _combo++;
          _timeLeft = (_timeLeft + 3.0).clamp(0.0, gameDurationSeconds.toDouble());
          effectText = "HEAL! +3s";
          break;
      }

      if (_isFeverMode && pointsEarned > 0) {
        pointsEarned *= 2;
        effectText = "FEVER! $effectText x2";
      }

      _score = max(0, _score + pointsEarned);

      if (_combo > _maxCombo) {
        _maxCombo = _combo;
      }

      // Trigger Fever Mode at 10 combo (if not already active)
      if (_combo >= 10 && !_isFeverMode) {
        _isFeverMode = true;
        _feverTimeLeft = 8.0; // 8 seconds of fever
        effectText = "FEVER MODE!";
      }

      // Instantly retract mole after a short visual delay, but for responsiveness,
      // we make it look hit immediately in the UI.
      notifyListeners();

      return {
        'success': isGoodHit,
        'points': pointsEarned,
        'type': mole.type,
        'text': effectText,
        'isFeverStart': _combo == 10 && _isFeverMode,
      };
    } else {
      // Whacked an empty hole! Break combo.
      if (_combo > 0) {
        _combo = 0;
        notifyListeners();
        return {
          'success': false,
          'points': 0,
          'type': null,
          'text': "MISS!",
          'isFeverStart': false,
        };
      }
    }

    return null;
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
}
