#!/usr/bin/env bash
# Boxy bootstrap: runs as root, installs apt deps, clones the repo as notion,
# and hands off to `make all`.
set -euo pipefail

NOTION_USER=notion
REPO=https://github.com/ehhong/notion-dotfiles.git
DEST=/home/$NOTION_USER/notion-dotfiles

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git make sudo

sudo -u "$NOTION_USER" -H bash -lc "
  set -euo pipefail
  if [ -d '$DEST/.git' ]; then
    cd '$DEST' && git pull --ff-only
  else
    git clone '$REPO' '$DEST' && cd '$DEST'
  fi
  make all
"
