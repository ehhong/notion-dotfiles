#!/usr/bin/env bash
# Boxy bootstrap: needs to run as the notion user so $HOME, the dotfiles
# clone, and symlinks all land in /home/notion. Boxy invokes this via
# `sudo -n -- ~/.boxy/profile/init.sh` (i.e. as root), so when invoked as root
# we re-exec as notion immediately; inline `sudo` calls below still work via
# passwordless sudo for apt.
#
# Fails loudly: preflight checks exit with a clear message, an ERR trap reports
# the failing line + command, every step echoes to both stdout and
# ~/.cache/boxy-init.log, and the script touches a success sentinel
# (~/.boxy-init-success) only if every step completes. Check that sentinel when
# debugging "why didn't my boxy bootstrap?" — boxy's own `.boxy_initialized`
# marker is written regardless of this script's exit status.
set -euo pipefail

# Boxy invokes this script as root via sudo. Drop privileges to notion before
# any HOME-based path resolution so logs, the clone, and symlinks land in
# /home/notion rather than /root.
if [[ "$(id -un)" == "root" ]]; then
	exec sudo -u notion -- "$0" "$@"
fi

REPO=https://github.com/ehhong/notion-dotfiles.git
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
	fail "This script must be run as notion (or root, which re-execs as notion), not $(id -un)."
fi

step "Preflight: verifying tooling"
command -v sudo >/dev/null 2>&1 || fail "sudo not found on PATH."

step "Installing apt prerequisites (git, make)"
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get update
sudo -E apt-get install -y git make

if [[ -d "$DEST/.git" ]]; then
	step "Updating existing clone at $DEST"
	cd "$DEST"
	git pull --ff-only
else
	step "Cloning $REPO into $DEST"
	git clone "$REPO" "$DEST"
	cd "$DEST"
fi

[[ -f "$DEST/Makefile" ]] || fail "Expected $DEST/Makefile after clone; repo layout changed?"

step "Running make all"
make all

step "Boxy bootstrap succeeded ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
date -u +%Y-%m-%dT%H:%M:%SZ > "$SUCCESS_SENTINEL"
