import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'sentence_timing.dart';

void main() => runApp(const ListenApp());

class ListenApp extends StatelessWidget {
  const ListenApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Listen · offline prototype',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: const PlayerScreen(),
      );
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  SentenceTimeline? _timeline;
  String _language = 'en';
  String? _error;
  int _selected = 0;
  bool _showTranscript = true;
  bool _repeatSentence = false;
  double _speed = 1;
  int? _aMs;
  int? _bMs;

  @override
  void initState() {
    super.initState();
    _player.positionStream.listen((position) {
      final timeline = _timeline;
      if (!mounted || timeline == null) return;
      final index = timeline.at(position.inMilliseconds);
      if (index != _selected && !_repeatSentence && _aMs == null) {
        setState(() => _selected = index);
      }
    });
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      await _player.stop();
      final raw = await rootBundle.loadString('assets/sentences_$_language.json');
      final entries = jsonDecode(raw) as List<dynamic>;
      final cues = entries.map((entry) {
        final value = entry as Map<String, dynamic>;
        return SentenceCue(value['startMs'] as int, value['endMs'] as int,
            value['text'] as String);
      }).toList();
      if (!mounted) return;
      setState(() {
        _timeline = SentenceTimeline(cues);
        _selected = 0;
        _aMs = null;
        _bMs = null;
        _repeatSentence = false;
        _error = 'Audio is not bundled yet. Playback is unavailable.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Cannot load local subtitles: $error');
    }
  }

  Future<void> _applyClip() async {
    final timeline = _timeline;
    if (timeline == null) return;
    final cue = timeline.cues[_selected];
    final start = _aMs ?? (_repeatSentence ? cue.startMs : null);
    final end = _bMs ?? (_repeatSentence ? cue.endMs : null);
    try {
      await _player.setClip(
        start: start == null ? null : Duration(milliseconds: start),
        end: end == null ? null : Duration(milliseconds: end),
      );
      await _player.setLoopMode(start == null ? LoopMode.off : LoopMode.one);
    } catch (error) {
      if (mounted) setState(() => _error = 'Audio not ready: $error');
    }
  }

  Future<void> _select(int index) async {
    final timeline = _timeline;
    if (timeline == null) return;
    setState(() {
      _selected = index;
      _aMs = null;
      _bMs = null;
    });
    await _applyClip();
    try {
      await _player.seek(Duration(milliseconds: timeline.cues[index].startMs));
    } catch (_) {
      // The subtitle-only checkpoint has no audio source yet.
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeline = _timeline;
    return Scaffold(
      appBar: AppBar(title: const Text('Listen · offline prototype')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Subtitle-only development preview; no audio or network.',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton.tonalIcon(
              onPressed: timeline == null ? null : () => _select(timeline.previous(_selected)),
              icon: const Icon(Icons.skip_previous),
              label: const Text('Previous'),
            ),
            FilledButton.tonalIcon(
              onPressed: null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play (audio pending)'),
            ),
            FilledButton.tonalIcon(
              onPressed: timeline == null ? null : () => _select(timeline.next(_selected)),
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
              await _player.setSpeed(value);
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
              onPressed: timeline == null ? null : () {
                setState(() => _aMs = timeline.cues[_selected].startMs);
                _applyClip();
              },
              child: const Text('Set A'),
            ),
            OutlinedButton(
              onPressed: timeline == null || _aMs == null ? null : () {
                final end = timeline.cues[_selected].endMs;
                try {
                  timeline.repeatRange(_aMs!, end);
                  setState(() => _bMs = end);
                  _applyClip();
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
