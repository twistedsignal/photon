#!/usr/bin/env bash
# Lint and run every test.
set -euo pipefail
# shellcheck source=scripts/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

cd "$PROJECT_ROOT"
selene="$(find_tool selene)"
lune="$(find_tool lune)"

"$PROJECT_ROOT/scripts/write-version.bash" >/dev/null
python3 "$PROJECT_ROOT/scripts/generate-loader.py"
"$selene" src
for test in tests/*.luau; do
	"$lune" run "$test"
done
