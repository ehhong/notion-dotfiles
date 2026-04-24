#!/usr/bin/env bash
# Boxy bootstrap: runs as notion (NOT root). Uses sudo inline for apt so that
# GH_TOKEN (which boxies inject into notion's interactive session but not into
# root's env) is preserved for `gh repo clone` on private repos.
#
# Fails loudly: preflight checks exit with a clear message, an ERR trap reports
# the failing line + command, every step echoes to both stdout and
# ~/.cache/boxy-init.log, and the script touches a success sentinel
# (~/.boxy-init-success) only if every step completes. Check that sentinel when
# debugging "why didn't my boxy bootstrap?" — boxy's own `.boxy_initialized`
# marker is written regardless of this script's exit status.

set -euo pipefail

SLUG=ehhong/notion-dotfiles
DEST=$HOME/notion-dotfiles
LOG=$HOME/.cache/boxy-init.log
SUCCESS_SENTINEL=$HOME/.boxy-init-success

mkdir -p "$(dirname "$LOG")"
# Mirror all output to the log so failures are recoverable after the session.
exec > >(tee -a "$LOG") 2>&1

step() { printf '\n[init.sh] %s\n' "$*"; }
fail() { printf '\n[init.sh] ERROR: %s\n' "$*" >&2; exit 1; }

on_err() {
	local exit_code=$? line=$1 cmd=$2
	printf '\n[init.sh] FAILED at line %s (exit %s): %s\n' "$line" "$exit_code" "$cmd" >&2
	printf '[init.sh] Full log: %s\n' "$LOG" >&2
	printf '[init.sh] Success sentinel NOT written; boxy bootstrap is incomplete.\n' >&2
}
trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR

# Clear the previous run's sentinel so a failure partway through is visible as
# a missing sentinel rather than a stale success.
rm -f "$SUCCESS_SENTINEL"

step "Starting boxy bootstrap ($(date -u +%Y-%m-%dT%H:%M:%SZ))"

if [[ "$(id -un)" != "notion" ]]; then
	fail "This script must be run as notion, not $(id -un). Invoke without sudo."
fi

step "Preflight: verifying tooling and GitHub access"

command -v gh >/dev/null 2>&1 || fail "gh CLI not found on PATH. Boxy should install it; check the base image."
command -v sudo >/dev/null 2>&1 || fail "sudo not found on PATH."

# GH_TOKEN is how boxy injects credentials for private-repo cloning. Without it
# `gh repo clone` can silently fall through to an interactive prompt (no tty →
# hangs or errors), so fail fast instead.
[[ -n "${GH_TOKEN:-}" ]] || fail "GH_TOKEN is not set. Boxy normally injects it; re-check the boxy profile."

if ! gh auth status >/dev/null 2>&1; then
	fail "gh is not authenticated. Run 'gh auth status' to see details."
fi

if ! gh repo view "$SLUG" >/dev/null 2>&1; then
	fail "gh cannot access $SLUG. Confirm the GH_TOKEN scopes include 'repo' and the account has access."
fi

step "Installing apt prerequisites (git, make)"
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get update
sudo -E apt-get install -y git make

if [[ -d "$DEST/.git" ]]; then
	step "Updating existing clone at $DEST"
	cd "$DEST"
	git pull --ff-only
else
	step "Cloning $SLUG into $DEST"
	gh repo clone "$SLUG" "$DEST"
	cd "$DEST"
fi

[[ -f "$DEST/Makefile" ]] || fail "Expected $DEST/Makefile after clone; repo layout changed?"

step "Running make all"
make all

step "Boxy bootstrap succeeded ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
date -u +%Y-%m-%dT%H:%M:%SZ > "$SUCCESS_SENTINEL"
