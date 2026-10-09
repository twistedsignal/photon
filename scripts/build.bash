#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

rojo="$(find_tool rojo)"

"$PROJECT_ROOT/scripts/clean.bash"
"$PROJECT_ROOT/scripts/write-version.bash"
mkdir -p "$PROJECT_ROOT/build"

cd "$PROJECT_ROOT"
"$rojo" build -o build/Photon.rbxm default.project.json
"$rojo" build -o build/PhotonLoader.rbxm loader.project.json
