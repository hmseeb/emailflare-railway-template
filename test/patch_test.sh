#!/bin/sh
# Applies scripts/patch_dockerfile.py to upstream's Dockerfile.email-api at the pinned
# UPSTREAM_SHA from build.yml and checks both patches landed:
#  1. workspace package node_modules are copied (server boots, r2 fix)
#  2. mesahub-core is fetched at an exact commit, never a moving branch (r3)
# Usage: test/patch_test.sh
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
WF=$HERE/.github/workflows/build.yml
SHA=$(sed -n 's/^ *UPSTREAM_SHA: *//p' "$WF")
MH=$(sed -n 's/^ *MESAHUB_CORE_SHA: *//p' "$WF")
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

echo "$MH" | grep -Eq '^[0-9a-f]{40}$' || fail "build.yml has no 40-char MESAHUB_CORE_SHA"
grep -q "MESAHUB_CORE_VERSION=\${{ env.MESAHUB_CORE_SHA }}" "$WF" || fail "build-args not wired to MESAHUB_CORE_SHA"
grep -q 'scripts/patch_dockerfile.py' "$WF" || fail "workflow does not run scripts/patch_dockerfile.py"

curl -sfL "https://raw.githubusercontent.com/0xdps/emailflare/$SHA/deploy/docker/Dockerfile.email-api" -o "$T/Dockerfile"
python3 -I "$HERE/scripts/patch_dockerfile.py" "$T/Dockerfile" || fail "patch script errored"
D=$T/Dockerfile

for p in services/email-server services/emails packages/email-core; do
  grep -q "^COPY --from=build-backend /app/$p/node_modules ./$p/node_modules$" "$D" || fail "missing node_modules copy for $p"
done
grep -q -- '--branch' "$D" && fail "mesahub-core still cloned by branch"
grep -q 'fetch -q --depth 1 https://github.com/mesahub-db/mesahub-core.git ${MESAHUB_CORE_VERSION}' "$D" || fail "mesahub-core not fetched by commit"
grep -q 'rev-parse HEAD)" = "${MESAHUB_CORE_VERSION}"' "$D" || fail "fetched commit not verified"
python3 -I "$HERE/scripts/patch_dockerfile.py" "$T/Dockerfile" 2>/dev/null && fail "second run should refuse (anchors gone)"
echo "PASS: patch_dockerfile.py ($SHA, mesahub-core $MH)"
