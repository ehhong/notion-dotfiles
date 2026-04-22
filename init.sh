#!/usr/bin/env bash
# Boxy bootstrap: runs as root, installs apt deps, clones the repo as notion
# (via gh CLI, since notion-dotfiles is private and boxies auth to GitHub with
# GH_TOKEN rather than an ssh key), then hands off to `make all`.
set -euo pipefail

NOTION_USER=notion
SLUG=ehhong/notion-dotfiles
DEST=/home/$NOTION_USER/notion-dotfiles

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git make sudo

sudo -u "$NOTION_USER" -H bash -lc "
  set -euo pipefail
  if [ -d '$DEST/.git' ]; then
    cd '$DEST' && git pull --ff-only
  else
    gh repo clone '$SLUG' '$DEST' && cd '$DEST'
  fi
  make all
"
