/// Turns a stream of camera frames into discrete scans.
///
/// A barcode held steadily in front of the camera is detected on every frame.
/// Each sighting refreshes its timestamp, so it counts once. It counts again
/// only after it has been out of view for [gap], which is what happens when
/// you move to the next unit of the same product.
class ScanGate {
  ScanGate({this.gap = const Duration(milliseconds: 700)});

  final Duration gap;

  final Map<String, DateTime> _lastSeen = {};

  /// True when [barcode] is a fresh scan. Always records the sighting, so call
  /// it for every detection, even ones you end up ignoring.
  bool accept(String barcode) {
    final now = DateTime.now();
    final last = _lastSeen[barcode];
    _lastSeen[barcode] = now;

    // Entries far past the gap can never matter again.
    _lastSeen.removeWhere((_, seen) => now.difference(seen) > gap * 10);

    return last == null || now.difference(last) >= gap;
  }
}
