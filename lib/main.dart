import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'player_backend.dart';
import 'sentence_timing.dart';

void main() => runApp(const ListenApp());

class ListenApp extends StatelessWidget {
  const ListenApp({super.key, this.backendFactory});

  final PlayerBackend Function()? backendFactory;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Listen · intensive listening prototype',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: PlayerScreen(backendFactory: backendFactory),
      );
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, this.backendFactory});

  final PlayerBackend Function()? backendFactory;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerBackend _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;

  SentenceTimeline? _timeline;
  String _language = 'en';
  String? _error;
  bool _audioReady = false;
  bool _isPlaying = false;
  int _selected = 0;
  int _positionMs = 0;
  int? _durationMs;
  bool _showTranscript = true;
  bool _repeatSentence = false;
  double _speed = 1;
  int? _aMs;
  int? _bMs;

  @override
  void initState() {
    super.initState();
    _player = widget.backendFactory?.call() ?? JustAudioPlayerBackend();
    _positionSub = _player.positionStream.listen(_handlePosition);
    _playingSub = _player.playingStream.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
    });
    _loadLanguage();
  }

  void _handlePosition(Duration position) {
    final timeline = _timeline;
    if (!mounted || timeline == null) return;

    final posMs = position.inMilliseconds;
    final loopRange = _activeLoopRange(timeline);

    if (loopRange != null && _isPlaying && posMs >= loopRange.$2) {
      unawaited(_player.seek(Duration(milliseconds: loopRange.$1)));
      setState(() => _positionMs = loopRange.$1);
      return;
    }

    final index = timeline.at(posMs);
    setState(() {
      _positionMs = posMs;
      if (!_repeatSentence && _aMs == null && index != _selected) {
        _selected = index;
      }
    });
  }

  (int, int)? _activeLoopRange(SentenceTimeline timeline) {
    if (_aMs != null && _bMs != null) {
      return (_aMs!, _bMs!);
    }
    if (_repeatSentence) {
      final cue = timeline.cues[_selected];
      return (cue.startMs, cue.endMs);
    }
    return null;
  }

  Future<void> _loadLanguage() async {
    try {
      await _player.stop();
      final raw = await rootBundle.loadString('assets/sentences_$_language.json');
      final entries = jsonDecode(raw) as List<dynamic>;
      final cues = entries.map((entry) {
        final value = entry as Map<String, dynamic>;
        return SentenceCue(
          value['startMs'] as int,
          value['endMs'] as int,
          value['text'] as String,
        );
      }).toList();
      final timeline = SentenceTimeline(cues);

      Duration? loadedDuration;
      String? audioError;
      var audioReady = false;
      try {
        loadedDuration =
            await _player.loadAsset('assets/sample_$_language.m4a');
        await _player.setSpeed(_speed);
        audioReady = true;
      } catch (error) {
        audioError = 'Audio unavailable: $error';
      }

      if (!mounted) return;
      setState(() {
        _timeline = timeline;
        _selected = 0;
        _positionMs = 0;
        _durationMs = loadedDuration?.inMilliseconds;
        _aMs = null;
        _bMs = null;
        _repeatSentence = false;
        _audioReady = audioReady;
        _error = audioError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _audioReady = false;
        _error = 'Cannot load local subtitles: $error';
      });
    }
  }

  Future<void> _applyClip() async {
    final timeline = _timeline;
    if (timeline == null || !_audioReady) return;
    final range = _activeLoopRange(timeline);
    try {
      await _player.setClip(
        start: range == null ? null : Duration(milliseconds: range.$1),
        end: range == null ? null : Duration(milliseconds: range.$2),
      );
      await _player.setLoopOne(range != null);
    } catch (error) {
      if (mounted) setState(() => _error = 'Audio not ready: $error');
    }
  }

  Future<void> _select(int index) async {
    final timeline = _timeline;
    if (timeline == null) return;
    final startMs = timeline.cues[index].startMs;
    setState(() {
      _selected = index;
      _positionMs = startMs;
      if (_aMs != null && _bMs != null) {
        _aMs = null;
        _bMs = null;
      }
    });
    await _applyClip();
    if (_audioReady) {
      try {
        await _player.seek(Duration(milliseconds: startMs));
      } catch (error) {
        if (mounted) setState(() => _error = 'Seek failed: $error');
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_audioReady) return;
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Playback failed: $error');
    }
  }

  String _formatMs(int ms) => '${(ms / 1000).toStringAsFixed(2)}s';

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeline = _timeline;
    final totalMs =
        _durationMs ?? (timeline == null ? 0 : timeline.cues.last.endMs);
    return Scaffold(
      appBar: AppBar(title: const Text('Listen · offline prototype')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
            'Offline intensive listening prototype (self-made sample audio, no network).',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'ja', label: Text('日本語')),
            ],
            selected: {_language},
            onSelectionChanged: (values) {
              setState(() => _language = values.first);
              _loadLanguage();
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, key: const Key('audio-status')),
            ),
          const SizedBox(height: 12),
          Text(
            'Position: ${_formatMs(_positionMs)} / ${_formatMs(totalMs)}',
            key: const Key('position-status'),
          ),
          if (_aMs != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _bMs == null
                    ? 'A–B: A=${_aMs}ms (select B)'
                    : 'A–B loop: ${_aMs}ms – ${_bMs}ms',
                key: const Key('ab-status'),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton.tonalIcon(
              onPressed: timeline == null
                  ? null
                  : () => _select(timeline.previous(_selected)),
              icon: const Icon(Icons.skip_previous),
              label: const Text('Previous'),
            ),
            FilledButton.icon(
              onPressed: _audioReady ? _togglePlayPause : null,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying ? 'Pause' : 'Play'),
            ),
            FilledButton.tonalIcon(
              onPressed: timeline == null
                  ? null
                  : () => _select(timeline.next(_selected)),
              icon: const Icon(Icons.skip_next),
              label: const Text('Next'),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Speed: ${_speed.toStringAsFixed(2)}×'),
          Slider(
            value: _speed,
            min: 0.5,
            max: 2,
            divisions: 6,
            label: '${_speed.toStringAsFixed(2)}×',
            onChanged: (value) async {
              setState(() => _speed = value);
              if (_audioReady) {
                await _player.setSpeed(value);
              }
            },
          ),
          SwitchListTile(
            title: const Text('Repeat selected sentence'),
            value: _repeatSentence,
            onChanged: (value) {
              setState(() {
                _repeatSentence = value;
                _aMs = null;
                _bMs = null;
              });
              _applyClip();
            },
          ),
          Wrap(spacing: 12, children: [
            OutlinedButton(
              onPressed: timeline == null
                  ? null
                  : () {
                      setState(() {
                        _aMs = timeline.cues[_selected].startMs;
                        _bMs = null;
                        _repeatSentence = false;
                      });
                      _applyClip();
                    },
              child: const Text('Set A'),
            ),
            OutlinedButton(
              onPressed: timeline == null || _aMs == null
                  ? null
                  : () async {
                      final end = timeline.cues[_selected].endMs;
                      try {
                        timeline.repeatRange(_aMs!, end);
                        setState(() => _bMs = end);
                        await _applyClip();
                        if (_audioReady) {
                          await _player.seek(Duration(milliseconds: _aMs!));
                        }
                      } on ArgumentError {
                        setState(() => _error = 'B must be after A.');
                      }
                    },
              child: const Text('Set B'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _aMs = null;
                  _bMs = null;
                });
                _applyClip();
              },
              child: const Text('Clear A–B'),
            ),
          ]),
          SwitchListTile(
            title: const Text('Show transcript'),
            value: _showTranscript,
            onChanged: (value) => setState(() => _showTranscript = value),
          ),
          if (_showTranscript && timeline != null)
            ...List.generate(timeline.cues.length, (index) {
              final cue = timeline.cues[index];
              return ListTile(
                selected: index == _selected,
                title: Text(cue.text, style: const TextStyle(fontSize: 20)),
                subtitle: Text('${cue.startMs}–${cue.endMs} ms'),
                onTap: () => _select(index),
              );
            }),
        ]),
      ),
    );
  }
}
