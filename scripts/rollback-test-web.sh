#!/usr/bin/env bash
# Roll back a test web release to an existing immutable commit directory.
set -euo pipefail
: "${AOS_TEST_RELEASE_ROOT:?set AOS_TEST_RELEASE_ROOT}"
: "${AOS_ROLLBACK_SHA:?set AOS_ROLLBACK_SHA}"
if [[ ! "$AOS_ROLLBACK_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'AOS_ROLLBACK_SHA must be a lowercase 40-character SHA' >&2
  exit 2
fi
if [[ "$AOS_TEST_RELEASE_ROOT" != /* || "$AOS_TEST_RELEASE_ROOT" == / || "$AOS_TEST_RELEASE_ROOT" == *'..'* ]]; then
  echo 'AOS_TEST_RELEASE_ROOT must be a safe absolute path' >&2
  exit 2
fi
root="${AOS_TEST_RELEASE_ROOT%/}"
if [[ ! -f "$root/releases/$AOS_ROLLBACK_SHA/index.html" || -L "$root/releases/$AOS_ROLLBACK_SHA" ]]; then
  echo 'Target release is absent or invalid' >&2
  exit 3
fi
link="$root/.rollback-$AOS_ROLLBACK_SHA-$$"
trap 'rm -f -- "$link"' EXIT
ln -s -- "releases/$AOS_ROLLBACK_SHA" "$link"
mv -Tf -- "$link" "$root/current"
trap - EXIT
printf 'Rolled back test web to %s\n' "$AOS_ROLLBACK_SHA"
