#!/usr/bin/env bash
# Boxy bootstrap: runs as notion (NOT root). Uses sudo inline for apt so that
# GH_TOKEN (which boxies inject into notion's interactive session but not into
# root's env) is preserved for `gh repo clone` on private repos.
set -euo pipefail

if [[ "$(id -un)" != "notion" ]]; then
  echo "This script must be run as notion, not $(id -un). Invoke without sudo." >&2
  exit 1
fi

SLUG=ehhong/notion-dotfiles
DEST=$HOME/notion-dotfiles

export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get update
sudo -E apt-get install -y git make

if [ -d "$DEST/.git" ]; then
  cd "$DEST"
  git pull --ff-only
else
  gh repo clone "$SLUG" "$DEST"
  cd "$DEST"
fi

make all
