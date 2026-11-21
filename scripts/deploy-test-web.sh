#!/usr/bin/env bash
# Prepare a versioned Flutter web release on an already-authorized test host.
set -euo pipefail

: "${AOS_WEB_BUILD_DIR:?set AOS_WEB_BUILD_DIR}"
: "${AOS_RELEASE_SHA:?set AOS_RELEASE_SHA}"
: "${AOS_TEST_RELEASE_ROOT:?set AOS_TEST_RELEASE_ROOT}"

if [[ ! "$AOS_RELEASE_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'AOS_RELEASE_SHA must be a 40-character lowercase commit SHA' >&2
  exit 2
fi
if [[ ! -d "$AOS_WEB_BUILD_DIR" || ! -f "$AOS_WEB_BUILD_DIR/index.html" ]]; then
  echo 'Flutter web build missing index.html' >&2
  exit 2
fi
if [[ "$AOS_TEST_RELEASE_ROOT" != /* || "$AOS_TEST_RELEASE_ROOT" == / || "$AOS_TEST_RELEASE_ROOT" == *'..'* ]]; then
  echo 'AOS_TEST_RELEASE_ROOT must be a safe absolute path' >&2
  exit 2
fi

root="${AOS_TEST_RELEASE_ROOT%/}"
release="$root/releases/$AOS_RELEASE_SHA"
mkdir -p "$root/releases"
if [[ -e "$release" ]]; then
  echo 'Release already exists; refusing to overwrite immutable release' >&2
  exit 3
fi
staging="$(mktemp -d "$root/releases/.staging.XXXXXXXX")"
cleanup() { [[ -d "$staging" ]] && rm -rf -- "$staging"; }
trap cleanup EXIT
cp -a -- "$AOS_WEB_BUILD_DIR"/. "$staging"/
mv -- "$staging" "$release"
trap - EXIT
ln -s -- "releases/$AOS_RELEASE_SHA" "$root/.current-$AOS_RELEASE_SHA"
mv -Tf -- "$root/.current-$AOS_RELEASE_SHA" "$root/current"
printf 'Published %s; previous release remains under %s/releases\n' "$AOS_RELEASE_SHA" "$root"
