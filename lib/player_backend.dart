import 'package:just_audio/just_audio.dart';

abstract class PlayerBackend {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;

  Future<Duration?> loadAsset(String assetPath);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setClip({Duration? start, Duration? end});
  Future<void> setLoopOne(bool enabled);
  Future<void> dispose();
}

class JustAudioPlayerBackend implements PlayerBackend {
  JustAudioPlayerBackend() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<Duration?> loadAsset(String assetPath) => _player.setAsset(assetPath);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setClip({Duration? start, Duration? end}) =>
      _player.setClip(start: start, end: end);

  @override
  Future<void> setLoopOne(bool enabled) =>
      _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);

  @override
  Future<void> dispose() => _player.dispose();
}
