/// A `Stopwatch` whose [elapsed] a test sets directly, instead of one that
/// actually measures wall-clock time.
///
/// Exists because `flutter_test`'s fake-async clock (`tester.pump(Duration)`)
/// virtualizes `Timer` scheduling, but **not** `Stopwatch.elapsed` — that
/// getter reads real elapsed wall-clock ticks no matter which `Zone` it runs
/// in. `ReservationCountdownNotifier` deliberately anchors on a `Stopwatch`
/// rather than `DateTime.now()` (GATE 1 §6 item 5), so a test that wants to
/// drive its countdown deterministically has to control *this* value in
/// lockstep with each `tester.pump(Duration(seconds: 1))` rather than
/// waiting on real time.
class ManualStopwatch implements Stopwatch {
  Duration manualElapsed = Duration.zero;

  @override
  Duration get elapsed => manualElapsed;

  @override
  int get elapsedMicroseconds => manualElapsed.inMicroseconds;

  @override
  int get elapsedMilliseconds => manualElapsed.inMilliseconds;

  @override
  int get elapsedTicks => manualElapsed.inMicroseconds;

  @override
  int get frequency => 1000000;

  @override
  bool get isRunning => true;

  @override
  void reset() => manualElapsed = Duration.zero;

  @override
  void start() {}

  @override
  void stop() {}
}
