class Throttler {
  final Duration interval;
  DateTime? _lastRun;

  Throttler({required this.interval});

  bool canRun() {
    final now = DateTime.now();
    if (_lastRun == null ||
        now.difference(_lastRun!) >= interval) {
      _lastRun = now;
      return true;
    }
    return false;
  }

  void run(void Function() action) {
    if (canRun()) {
      action();
    }
  }

  void reset() {
    _lastRun = null;
  }
}
