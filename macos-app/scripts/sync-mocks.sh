#!/usr/bin/env bash
# Copy the contract mock fixtures into the Core package resources so the mock
# backend and tests read the SAME JSON the contract defines. contracts/ stays
# the single source of truth; these copies are build inputs.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/../../contracts/mock"
dst="$here/../../apple-core/Sources/MiniVPNCore/Resources/Mocks"
mkdir -p "$dst"
shopt -s nullglob
count=0
for f in "$src"/*.json; do
  cp "$f" "$dst/"
  count=$((count + 1))
done
echo "synced $count mocks -> $dst"
