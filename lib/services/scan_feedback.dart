import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// What a scan meant, which decides the sound and the vibration.
enum ScanTone {
  /// A normal scan: one clean beep, one short pulse.
  scanned,

  /// A barcode that is already known: rising two-note chirp, double pulse.
  duplicate,

  /// A barcode that was not found: low double buzz, long double pulse.
  unknown,
}

/// Beep and vibrate on every scan. Tones ship in the app bundle, so this works
/// in Airplane Mode. Every failure is swallowed: feedback must never get in
/// the way of scanning.
class ScanFeedback {
  ScanFeedback._(this._players, this._hasVibrator);

  static const Map<ScanTone, String> _assets = {
    ScanTone.scanned: 'sounds/scan.wav',
    ScanTone.duplicate: 'sounds/duplicate.wav',
    ScanTone.unknown: 'sounds/unknown.wav',
  };

  /// Plays over the media volume without taking audio focus, so music or a
  /// call app is not paused by a beep.
  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  final Map<ScanTone, AudioPlayer> _players;
  final bool _hasVibrator;

  static Future<ScanFeedback> load() async {
    final players = <ScanTone, AudioPlayer>{};
    try {
      for (final entry in _assets.entries) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setAudioContext(_context);
        await player.setSource(AssetSource(entry.value));
        players[entry.key] = player;
      }
    } catch (_) {
      // Run silently rather than fail to start.
    }

    var hasVibrator = false;
    try {
      hasVibrator = await Vibration.hasVibrator();
    } catch (_) {}

    return ScanFeedback._(players, hasVibrator);
  }

  /// Fire and forget, so the caller never waits on audio.
  void play(ScanTone tone) {
    unawaited(_beep(tone));
    unawaited(_vibrate(tone));
  }

  Future<void> _beep(ScanTone tone) async {
    final player = _players[tone];
    if (player == null) return;
    try {
      await player.stop();
      await player.resume();
    } catch (_) {}
  }

  Future<void> _vibrate(ScanTone tone) async {
    try {
      if (!_hasVibrator) {
        await HapticFeedback.mediumImpact();
        return;
      }
      switch (tone) {
        case ScanTone.scanned:
          await Vibration.vibrate(duration: 45);
        case ScanTone.duplicate:
          await Vibration.vibrate(pattern: [0, 45, 70, 45]);
        case ScanTone.unknown:
          await Vibration.vibrate(pattern: [0, 160, 80, 160]);
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
  }
}
