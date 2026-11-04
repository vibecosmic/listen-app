# ADR 0001: Pure sentence timeline before audio integration

Status: proposed (F001 incremental checkpoint, 2026-11-02).

Decision: model subtitle cues as ordered half-open millisecond intervals, validate
overlaps, and keep navigation and A-B validation independent of the audio engine.
The next step is a Flutter screen using just_audio setClip and loop controls,
with independently created/licensed local English and Japanese recordings.

Alternatives: position-index arithmetic inside widgets (hard to test), or
server-derived timing (violates offline prototype). Pure timing isolates boundary
regressions and allows synthetic tests without uploading media.

This checkpoint does **not** contain playback UI, sample recordings, a generated
pubspec.lock, or physical-device measurements. It is not F001 acceptance.
