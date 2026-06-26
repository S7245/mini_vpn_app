#!/usr/bin/env bash
# Copy the contract mock fixtures into rust-core so the mock BackendService and
# its tests read the SAME JSON the contract defines (embedded via include_str!).
# contracts/ stays the single source of truth; these copies are build inputs —
# never hand-edit them. Mirrors macos-app/scripts/sync-mocks.sh.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/../../contracts/mock"
dst="$here/../fixtures"
mkdir -p "$dst"
shopt -s nullglob
count=0
for f in "$src"/*.json; do
  cp "$f" "$dst/"
  count=$((count + 1))
done
echo "synced $count mocks -> $dst"
