enum MoleType {
  normal,
  golden,
  spiky,
  nurse,
}

class MoleState {
  final int id;
  MoleType type;
  bool isUp;
  bool isHit;
  DateTime? spawnTime;
  Duration duration;

  MoleState({
    required this.id,
    this.type = MoleType.normal,
    this.isUp = false,
    this.isHit = false,
    this.spawnTime,
    this.duration = const Duration(seconds: 2),
  });

  void popUp(MoleType newType, Duration newDuration) {
    type = newType;
    isUp = true;
    isHit = false;
    spawnTime = DateTime.now();
    duration = newDuration;
  }

  void retreat() {
    isUp = false;
    isHit = false;
    spawnTime = null;
  }

  bool shouldRetreat() {
    if (!isUp) return false;
    if (spawnTime == null) return true;
    return DateTime.now().difference(spawnTime!) >= duration;
  }

  void hit() {
    isHit = true;
  }
}
