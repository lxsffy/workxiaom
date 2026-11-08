#!/bin/zsh
# Copyright (c) 2026 FanXeon@Poemcoder with Codex
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/project.sh"
CODEX_ACCESSIBILITY_SCRIPT="${MI_AO_CODEX_ACCESSIBILITY_SCRIPT:-$ROOT/scripts/codex-accessibility.sh}"
OPEN_BIN="${MI_AO_OPEN_BIN:-/usr/bin/open}"

# PATCH (local workaround for this environment):
# `open --args` does NOT inject argv into the app/Codex on this machine, so the
# normal launch chain (start.sh -> run-with-mapping.sh -> run.sh -> open -n --args run)
# never reaches .run mode and the codex-accessibility `ensure` gate aborts startup.
# We therefore (1) skip the compatibility `ensure` gate and (2) exec the binary
# directly with --force-submit, keeping it inside the LaunchServices GUI session so
# it persists. --force-submit pastes via Cmd+V+Return (no AX tree needed), so the
# missing --force-renderer-accessibility flag on Codex is irrelevant.
needs_codex_compatibility=false

if [[ ! -x "$INSTALLED_BIN" ]]; then
  "$ROOT/scripts/install-app.sh"
fi

if [[ "${MI_AO_LAUNCH_VIA_OPEN:-0}" == "1" ]]; then
  exec "$INSTALLED_BIN" run "$@" --force-submit --submit-to com.tencent.workbuddy.mac
fi

exec "$INSTALLED_BIN" run "$@" --force-submit --submit-to com.tencent.workbuddy.mac
