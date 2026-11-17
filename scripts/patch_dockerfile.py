#!/usr/bin/env python3
"""Patch upstream deploy/docker/Dockerfile.email-api in place. Each anchor must match exactly once.

1. Upstream copies node_modules/.pnpm but not each workspace package's node_modules symlinks,
   so the server dies with "Cannot find package '@hono/node-server'". The symlinks are
   relative into /app/node_modules/.pnpm, which is copied.
2. Upstream clones mesahub-core by branch (trunk), an unpinned moving input. Fetch the exact
   commit passed as MESAHUB_CORE_VERSION (40-char SHA) and verify HEAD equals it.

Usage: patch_dockerfile.py <Dockerfile>
"""
import pathlib
import sys

COPY_ANCHOR = "COPY --from=build-backend /app/services/email-server/dist     ./services/email-server/dist\n"
COPY_ADD = "".join(
    f"COPY --from=build-backend /app/{p}/node_modules ./{p}/node_modules\n"
    for p in ("services/email-server", "services/emails", "packages/email-core")
)
CLONE_OLD = (
    "    git clone --depth 1 --branch ${MESAHUB_CORE_VERSION} \\\n"
    "    https://github.com/mesahub-db/mesahub-core.git /mesahub-core\n"
)
CLONE_NEW = (
    "    git init -q /mesahub-core && \\\n"
    "    git -C /mesahub-core fetch -q --depth 1 https://github.com/mesahub-db/mesahub-core.git ${MESAHUB_CORE_VERSION} && \\\n"
    "    git -C /mesahub-core checkout -q FETCH_HEAD && \\\n"
    '    test "$(git -C /mesahub-core rev-parse HEAD)" = "${MESAHUB_CORE_VERSION}"\n'
)


def main(path):
    f = pathlib.Path(path)
    s = f.read_text()
    for old, new in ((COPY_ANCHOR, COPY_ANCHOR + COPY_ADD), (CLONE_OLD, CLONE_NEW)):
        n = s.count(old)
        if n != 1:
            sys.exit(f"anchor matched {n} times, expected 1: {old.splitlines()[0].strip()}")
        s = s.replace(old, new)
    f.write_text(s)


if __name__ == "__main__":
    main(sys.argv[1])
