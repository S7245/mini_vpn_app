#!/usr/bin/env bash
# Copy the contract mock fixtures into the Core package resources so the mock
# backend and tests read the SAME JSON the contract defines. contracts/ stays
# the single source of truth; these copies are build inputs.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/../../contracts/mock"
dst="$here/../Core/Sources/MiniVPNCore/Resources/Mocks"
mkdir -p "$dst"
for f in user token-pair subscription device device-list node-list select-best; do
  cp "$src/$f.json" "$dst/$f.json"
done
echo "synced mocks -> $dst"
