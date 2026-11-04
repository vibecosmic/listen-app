/// Pure, testable sentence timing model. All offsets are milliseconds.
class SentenceCue {
  const SentenceCue(this.startMs, this.endMs, this.text);
  final int startMs;
  final int endMs;
  final String text;
}

class SentenceTimeline {
  SentenceTimeline(List<SentenceCue> cues) : cues = List.unmodifiable(cues) {
    if (cues.isEmpty) throw ArgumentError('At least one cue is required');
    for (var i = 0; i < cues.length; i++) {
      if (cues[i].startMs < 0 || cues[i].endMs <= cues[i].startMs) {
        throw ArgumentError('Invalid cue range at $i');
      }
      if (i > 0 && cues[i].startMs < cues[i - 1].endMs) {
        throw ArgumentError('Overlapping or unordered cues at $i');
      }
    }
  }

  final List<SentenceCue> cues;

  int at(int positionMs) {
    if (positionMs <= cues.first.startMs) return 0;
    for (var i = 0; i < cues.length; i++) {
      if (positionMs < cues[i].startMs) return i - 1;
      if (positionMs < cues[i].endMs) return i;
    }
    return cues.length - 1;
  }

  int previous(int current) => current <= 0 ? 0 : current - 1;
  int next(int current) => current >= cues.length - 1 ? cues.length - 1 : current + 1;

  /// Inclusive A, exclusive B; never permit a zero-length repeat.
  (int, int) repeatRange(int aMs, int bMs) {
    if (aMs < 0 || bMs <= aMs || bMs > cues.last.endMs) {
      throw ArgumentError('Invalid A-B range');
    }
    return (aMs, bMs);
  }
}
