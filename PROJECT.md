# listen-app

Public frontend component of the listening-practice app (AOS project `listen`).
Private requirements, research and the backend live in a separate private repository;
only sanitized, public-safe context belongs here.

Goal: a mobile listening-practice app for English and Japanese learners (children and
adults). Focus: sentence-by-sentence intensive listening on media the user saves to
their own device, with subtitles (fetched or generated), sentence segmentation, loop
and A-B repeat, transcript toggle, and tap-to-look-up words (Japanese word
segmentation). Shadowing comes later. Framework and media pipeline are still being
researched; do not lock them in before that research is reviewed.

Constraints:
- Sign-in uses the shared account service via OIDC (authorization code + PKCE S256);
  no separate auth system in the frontend.
- Talk to the backend only through its versioned public API contract.
- Children are among the users: collect the minimum data, no ads/trackers.
- No secrets, private user data, recordings or unlicensed audio/text in this repository.
- No paid API, deployment or release without separate authorization.
- License: not chosen yet (Operator decision). Public visibility is not a license.
