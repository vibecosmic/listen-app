# listen-app

Public frontend component of the listening-practice app (AOS project `listen`).
Private requirements, research and the backend live in a separate private repository;
only sanitized, public-safe context belongs here.

Goal: a listening-practice client. Candidate features (not committed until product
planning is reviewed): audio player with speed control, sentence-level seek and loop,
A-B repeat, show/hide transcript with sentence highlighting, dictation mode, and
practice history.

Constraints:
- Sign-in uses the shared account service via OIDC (authorization code + PKCE S256);
  no separate auth system in the frontend.
- Talk to the backend only through its versioned public API contract.
- No secrets, private user data, recordings or unlicensed audio/text in this repository.
- No paid API, deployment or release without separate authorization.
- License: not chosen yet (Operator decision). Public visibility is not a license.
