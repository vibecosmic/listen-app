import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:listen_app/main.dart';
import 'package:listen_app/player_backend.dart';
import 'package:material_ui/material_ui.dart';

class FakePlayerBackend implements PlayerBackend {
  FakePlayerBackend({this.failLoad = false});

  final bool failLoad;
  final _positionController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();

  final List<String> loadedAssets = [];
  final List<Duration> seeks = [];
  final List<double> speeds = [];
  final List<(Duration?, Duration?)> clips = [];
  final List<bool> loopStates = [];
  bool isPlaying = false;
  bool disposed = false;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  void emitPosition(Duration position) => _positionController.add(position);

  @override
  Future<Duration?> loadAsset(String assetPath) async {
    loadedAssets.add(assetPath);
    if (failLoad) {
      throw StateError('Asset load failed');
    }
    return const Duration(milliseconds: 2000);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    _playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    speeds.add(speed);
  }

  @override
  Future<void> setClip({Duration? start, Duration? end}) async {
    clips.add((start, end));
  }

  @override
  Future<void> setLoopOne(bool enabled) async {
    loopStates.add(enabled);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _positionController.close();
    await _playingController.close();
  }
}

void main() {
  testWidgets('loads audio asset, toggles play/pause, and switches language',
      (tester) async {
    final backend = FakePlayerBackend();
    await tester.pumpWidget(ListenApp(backendFactory: () => backend));
    await tester.pumpAndSettle();

    expect(backend.loadedAssets, ['assets/sample_en.m4a']);
    expect(find.byKey(const Key('audio-status')), findsNothing);
    expect(find.text('Position: 0.00s / 2.00s'), findsOneWidget);
    expect(find.text('Hello.'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(backend.isPlaying, isTrue);
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(backend.isPlaying, isFalse);
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.text('日本語'));
    await pumpLoaded(tester);
    expect(backend.loadedAssets, [
      'assets/sample_en.m4a',
      'assets/sample_ja.m4a',
    ]);
    expect(find.text('こんにちは。'), findsOneWidget);
  });

  testWidgets('sentence navigation, speed, repeat and A-B loop controls work',
      (tester) async {
    final backend = FakePlayerBackend();
    await tester.pumpWidget(ListenApp(backendFactory: () => backend));
    await pumpLoaded(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(backend.seeks.last, const Duration(milliseconds: 1000));

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(backend.seeks.last, Duration.zero);

    await tester.tap(find.text('Repeat selected sentence'));
    await tester.pumpAndSettle();
    expect(backend.clips.last, (Duration.zero, const Duration(milliseconds: 1000)));
    expect(backend.loopStates.last, isTrue);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    backend.emitPosition(const Duration(milliseconds: 1050));
    await tester.pumpAndSettle();
    expect(backend.seeks.last, Duration.zero);

    await tester.tap(find.text('Set A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set B'));
    await tester.pumpAndSettle();

    expect(
      backend.clips.last,
      (Duration.zero, const Duration(milliseconds: 2000)),
    );
    expect(find.text('A–B loop: 0ms – 2000ms'), findsOneWidget);

    await tester.tap(find.text('Clear A–B'));
    await tester.pumpAndSettle();
    expect(backend.loopStates.last, isFalse);
    expect(find.byKey(const Key('ab-status')), findsNothing);
  });

  testWidgets('transcript toggle and graceful audio error fallback',
      (tester) async {
    final backend = FakePlayerBackend(failLoad: true);
    await tester.pumpWidget(ListenApp(backendFactory: () => backend));
    await pumpLoaded(tester);

    expect(find.byKey(const Key('audio-status')), findsOneWidget);
    expect(find.text('Hello.'), findsOneWidget);

    await tester.tap(find.text('Show transcript'));
    await tester.pumpAndSettle();
    expect(find.text('Hello.'), findsNothing);
  });
}
