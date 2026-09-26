#!/usr/bin/env bash
# The goldens image's entrypoint: `flutter test` on a copy of the tree at /src.
#
# The tree is copied rather than used in place so that the host's .dart_tool
# and build/ (which hold host paths) are never read or rewritten from Linux.
# Only goldens come back: the PNGs --update-goldens wrote, and the diffs of any
# golden that failed, under test/goldens/failures/ (ignored by git).
set -euo pipefail

rsync -a --delete \
  --exclude=/.dart_tool/ --exclude=/build/ --exclude=/.git/ --exclude=/.idea/ \
  --exclude=/test/goldens/failures/ \
  /src/ /work/
cd /work
# Diffs from an earlier run would read as this one's.
rm -rf /src/test/goldens/failures
# The bundle declares .env, which is untracked; the tests never read it.
[ -f .env ] || cp .env.example .env

# Names the environment for test/goldens/golden.dart, which compares only when
# this matches the one the committed goldens were made in.
framework=$(flutter --version --machine | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p')
export HELIX_GOLDEN_ENV="flutter-${framework}-linux-$(uname -m)"
echo "golden environment: ${HELIX_GOLDEN_ENV}"
# Skia picks its SIMD code path from the CPU at run time. The goldens were made
# on an AVX2 CPU without AVX-512; if a run ever differs by a pixel here and
# nowhere else, this line is the first thing to compare.
echo "cpu: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)" \
  "| avx2: $(grep -qw avx2 /proc/cpuinfo && echo yes || echo no)" \
  "| avx512f: $(grep -qw avx512f /proc/cpuinfo && echo yes || echo no)"

flutter pub get --enforce-lockfile > /dev/null

status=0
flutter test "$@" || status=$?

for arg in "$@"; do
  if [ "$arg" = --update-goldens ]; then
    rsync -a --prune-empty-dirs --exclude=/goldens/failures/ \
      --include='*/' --include='goldens/**.png' --exclude='*' \
      /work/test/ /src/test/
    echo 'regenerated goldens copied back to the host tree'
  fi
done
if [ -d /work/test/goldens/failures ]; then
  cp -r /work/test/goldens/failures /src/test/goldens/failures
  echo 'golden diffs copied to test/goldens/failures/'
fi
exit "$status"
