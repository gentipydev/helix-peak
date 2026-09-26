#!/usr/bin/env bash
# `flutter test` in the golden environment, from any host with Docker.
#
#   tool/goldens/goldens.sh                     # the whole suite, goldens included
#   tool/goldens/goldens.sh test/goldens        # the goldens alone
#   tool/goldens/goldens.sh --update-goldens test/goldens/walk_surfaces_test.dart
#
# Arguments go to `flutter test` unchanged. The image is built from the
# Dockerfile beside this script the first time, and reused after that.
# docs/goldens.md says when regenerating is allowed. Never to make a session pass.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
version="$(sed -n 's/^ARG FLUTTER_VERSION=//p' "$here/Dockerfile")"
image="helixpeak-goldens:${version}"

docker build --quiet --tag "$image" "$here" > /dev/null

# Git Bash on Windows: docker wants a Windows path for the mount, and MSYS must
# not rewrite /src into one.
if command -v cygpath > /dev/null; then
  root="$(cygpath -w "$root")"
  export MSYS_NO_PATHCONV=1
fi

exec docker run --rm \
  --platform linux/amd64 \
  --volume "${root}:/src" \
  --volume helixpeak-pub-cache:/pub-cache \
  "$image" "$@"
