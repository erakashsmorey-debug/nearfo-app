import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Manages all call-related sounds: ringback tone, ringtone, connected beep, ended beep.
///
/// - Caller hears ringback (tring-tring) while waiting for recipient to answer.
/// - Receiver hears ringtone when incoming call arrives.
/// - Both hear a short beep when the call connects.
/// - Both hear 3 short beeps when the call ends.
class CallSoundService {
  CallSoundService._();
  static final CallSoundService instance = CallSoundService._();

  AudioPlayer? _tonePlayer;
  bool _isPlaying = false;

  /// Play ringback tone (caller side — "tring tring" while ringing).
  /// Loops until stopped.
  Future<void> playRingback() async {
    await stop();
    try {
      _tonePlayer = AudioPlayer();
      await _tonePlayer!.setReleaseMode(ReleaseMode.loop);
      await _tonePlayer!.setVolume(0.7);
      await _tonePlayer!.play(AssetSource('sounds/ringback.wav'));
      _isPlaying = true;
      debugPrint('[CallSound] Playing ringback tone');
    } catch (e) {
      debugPrint('[CallSound] Error playing ringback: $e');
    }
  }

  /// Play ringtone (receiver side — incoming call ringing).
  /// Loops until stopped.
  Future<void> playRingtone() async {
    await stop();
    try {
      _tonePlayer = AudioPlayer();
      await _tonePlayer!.setReleaseMode(ReleaseMode.loop);
      await _tonePlayer!.setVolume(0.85);
      await _tonePlayer!.play(AssetSource('sounds/ringtone.wav'));
      _isPlaying = true;
      debugPrint('[CallSound] Playing ringtone');
    } catch (e) {
      debugPrint('[CallSound] Error playing ringtone: $e');
    }
  }

  /// Play short "connected" beep (both sides — call established).
  Future<void> playConnected() async {
    await stop();
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(0.5);
      await player.play(AssetSource('sounds/call_connected.wav'));
      // Auto-dispose after playback
      player.onPlayerComplete.listen((_) => player.dispose());
      debugPrint('[CallSound] Playing connected beep');
    } catch (e) {
      debugPrint('[CallSound] Error playing connected beep: $e');
    }
  }

  /// Play short "call ended" beeps (both sides).
  Future<void> playEnded() async {
    await stop();
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(0.5);
      await player.play(AssetSource('sounds/call_ended.wav'));
      player.onPlayerComplete.listen((_) => player.dispose());
      debugPrint('[CallSound] Playing ended beep');
    } catch (e) {
      debugPrint('[CallSound] Error playing ended beep: $e');
    }
  }

  /// Stop the currently looping tone (ringback or ringtone).
  Future<void> stop() async {
    if (_tonePlayer != null) {
      try {
        await _tonePlayer!.stop();
        await _tonePlayer!.dispose();
      } catch (e) {
        debugPrint('[CallSound] Error stopping tone: $e');
      }
      _tonePlayer = null;
      _isPlaying = false;
      debugPrint('[CallSound] Tone stopped');
    }
  }

  bool get isPlaying => _isPlaying;
}
