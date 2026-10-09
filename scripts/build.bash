#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

rojo="$(find_tool rojo)"
lune="$(find_tool lune)"

"$PROJECT_ROOT/scripts/clean.bash"
"$PROJECT_ROOT/scripts/write-version.bash"
python3 "$PROJECT_ROOT/scripts/generate-loader.py"
mkdir -p "$PROJECT_ROOT/build"

cd "$PROJECT_ROOT"
"$lune" run scripts/write-loader.luau
"$rojo" build -o build/Photon.rbxm default.project.json
"$rojo" build -o build/PhotonLoader.rbxm loader.project.json
