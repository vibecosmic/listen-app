# Task queue

GitHub Issues are the execution state; roles pull work, nothing is preassigned.

- F001 / implementer / pr: intensive-listening player prototype in Flutter (just_audio), using bundled self-made or public-domain sample audio and subtitles: play/pause,
  speed, sentence seek and loop, A-B repeat, transcript toggle with highlighting. Prefer m4a
  (accurate seek tables); measure loop-boundary accuracy and pitch at changed speeds.
- F002 / reviewer / report / hold: review F001 for accessibility (including children),
  mobile playback and privacy; starts after the F001 PR.
- F003 / implementer / pr (Issue #4): CI builds the Flutter web version on every PR and publishes it to the
  team test server on each push to `main`; the deploy job stays skipped until the test server and
  its deploy settings exist.
