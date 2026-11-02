import 'package:flutter_test/flutter_test.dart';
import 'package:listen_player/sentence_timing.dart';

void main() {
  final timeline = SentenceTimeline([
    const SentenceCue(0, 1000, 'one'),
    const SentenceCue(1200, 2200, 'two'),
    const SentenceCue(2200, 3000, 'three'),
  ]);

  test('half-open cue boundaries and gaps', () {
    expect(timeline.at(0), 0);
    expect(timeline.at(999), 0);
    expect(timeline.at(1000), 1);
    expect(timeline.at(2199), 1);
    expect(timeline.at(2200), 2);
    expect(timeline.at(5000), 2);
  });
  test('navigation clamps at both ends', () {
    expect(timeline.previous(0), 0);
    expect(timeline.next(2), 2);
    expect(timeline.next(0), 1);
  });
  test('rejects invalid and overlapping cues', () {
    expect(() => SentenceTimeline([]), throwsArgumentError);
    expect(() => SentenceTimeline([const SentenceCue(0, 1000, 'a'), const SentenceCue(900, 1500, 'b')]), throwsArgumentError);
    expect(() => SentenceTimeline([const SentenceCue(5, 5, 'a')]), throwsArgumentError);
  });
  test('A-B range rejects reversed and out-of-bounds values', () {
    expect(timeline.repeatRange(200, 600), (200, 600));
    expect(() => timeline.repeatRange(600, 600), throwsArgumentError);
    expect(() => timeline.repeatRange(-1, 500), throwsArgumentError);
    expect(() => timeline.repeatRange(0, 4000), throwsArgumentError);
  });
}
