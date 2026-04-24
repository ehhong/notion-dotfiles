SHELL := /bin/bash

REPO_ROOT        := $(CURDIR)
HOME_DIR         := $(HOME)
NVIM_VERSION     := v0.11.2
LAZYGIT_VERSION  := v0.44.1

.DEFAULT_GOAL := help
.PHONY: all deps fish symlinks nvim lazygit warmup clean help

all: deps fish symlinks nvim lazygit warmup  ## full boxy bootstrap (deps → fish → symlinks → nvim → lazygit → warmup)

help:  ## list targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps:  ## apt packages (git, curl, ripgrep, fd, build-essential)
	sudo DEBIAN_FRONTEND=noninteractive apt-get update
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
		git curl unzip ripgrep fd-find build-essential tar
	@if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then \
		sudo ln -sf "$$(command -v fdfind)" /usr/local/bin/fd; \
		echo "Linked fdfind → /usr/local/bin/fd"; \
	fi

fish:  ## install fish (login shell is left as bash/zsh; .bashrc + .zshrc exec fish for interactive sessions)
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fish
	@current="$$(getent passwd "$$USER" | cut -d: -f7)"; \
	case "$$current" in \
		*/fish) \
			echo "Reverting login shell from fish to /bin/bash (interactive fish handoff is in ~/.bashrc / ~/.zshrc)"; \
			sudo chsh -s /bin/bash "$$USER"; \
			;; \
		*) \
			echo "Login shell is $$current (leaving as-is; ~/.bashrc and ~/.zshrc exec fish for interactive sessions)"; \
			;; \
	esac

symlinks:  ## mirror home/ into $HOME as symlinks (idempotent)
	@set -euo pipefail; \
	find "$(REPO_ROOT)/home" -mindepth 1 -type d | while read -r dir; do \
		rel="$${dir#$(REPO_ROOT)/home/}"; \
		mkdir -p "$(HOME_DIR)/$$rel"; \
	done; \
	find "$(REPO_ROOT)/home" -type f | while read -r src; do \
		rel="$${src#$(REPO_ROOT)/home/}"; \
		dst="$(HOME_DIR)/$$rel"; \
		if [[ -e "$$dst" && ! -L "$$dst" ]]; then \
			echo "backup: $$dst → $$dst.bak"; \
			mv "$$dst" "$$dst.bak"; \
		fi; \
		ln -sfn "$$src" "$$dst"; \
	done; \
	echo "Symlinks in place under $(HOME_DIR)"

nvim:  ## install Neovim $(NVIM_VERSION) to ~/.local/bin (tarball → source fallback)
	@NVIM_VERSION="$(NVIM_VERSION)" bash -c "$$NVIM_INSTALL_SCRIPT"
	@# Symlink into /usr/local/bin so any shell finds it without PATH changes.
	sudo ln -sf "$$HOME/.local/bin/nvim" /usr/local/bin/nvim
	@echo "nvim: $$(/usr/local/bin/nvim --version | head -1)"

lazygit:  ## install lazygit $(LAZYGIT_VERSION) to ~/.local/bin (prebuilt tarball)
	@LAZYGIT_VERSION="$(LAZYGIT_VERSION)" bash -c "$$LAZYGIT_INSTALL_SCRIPT"
	@# Symlink into /usr/local/bin so any shell finds it without PATH changes.
	sudo ln -sf "$$HOME/.local/bin/lazygit" /usr/local/bin/lazygit
	@echo "lazygit: $$(/usr/local/bin/lazygit --version | head -1)"

warmup:  ## kick Lazy restore + TSInstallSync + Mason in background
	@bash -c "$$NVIM_WARMUP_SCRIPT"

clean:  ## remove symlinks created by `symlinks` (leaves .bak files alone)
	@set -euo pipefail; \
	find "$(REPO_ROOT)/home" -type f | while read -r src; do \
		rel="$${src#$(REPO_ROOT)/home/}"; \
		dst="$(HOME_DIR)/$$rel"; \
		if [[ -L "$$dst" && "$$(readlink "$$dst")" == "$$src" ]]; then \
			rm -f "$$dst" && echo "removed: $$dst"; \
		fi; \
	done

define NVIM_INSTALL_SCRIPT
set -euo pipefail
export PATH="$$HOME/.local/bin:$$PATH"

desired="$${NVIM_VERSION}"
if command -v nvim >/dev/null 2>&1; then
	current="$$(nvim --version 2>/dev/null | head -n1 | awk '{print $$2}')"
	if [[ "$$current" == "$$desired" ]]; then
		echo "nvim $$desired already installed"
		exit 0
	fi
fi

work_dir="$$HOME/.cache/nvim-install-$${desired}"
tarball="$$work_dir/nvim-linux-x86_64.tar.gz"
release_url="https://github.com/neovim/neovim-releases/releases/download/$${desired}/nvim-linux-x86_64.tar.gz"
install_dir="$$HOME/.local/opt/nvim-$${desired}"

mkdir -p "$$HOME/.local/bin" "$$HOME/.local/opt" "$$work_dir"

# Prefer the neovim-releases tarball (built against older glibc so it runs on
# debian-bullseye). Canonical nvim tarballs >= 0.10 won't run there.
if curl -fL --retry 3 --retry-delay 2 -o "$$tarball" "$$release_url"; then
	rm -rf "$$install_dir"
	mkdir -p "$$install_dir"
	tar -xzf "$$tarball" -C "$$install_dir" --strip-components=1
	ln -sf "$$install_dir/bin/nvim" "$$HOME/.local/bin/nvim"
	installed="$$("$$HOME/.local/bin/nvim" --version 2>/dev/null | head -n1 | awk '{print $$2}')"
	if [[ "$$installed" == "$$desired" ]]; then
		echo "Installed Neovim $$desired from neovim-releases tarball"
		exit 0
	fi
fi

echo "Prebuilt Neovim failed; building from source..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
	build-essential cmake ninja-build gettext pkg-config \
	unzip libtool libtool-bin autoconf automake g++

build_dir="$$HOME/.cache/nvim-build-$${desired}"
rm -rf "$$build_dir"
git clone --depth 1 --branch "$${desired}" https://github.com/neovim/neovim.git "$$build_dir"
cd "$$build_dir"
jobs="$$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$$HOME/.local" -j"$$jobs"
make install
endef
export NVIM_INSTALL_SCRIPT

define LAZYGIT_INSTALL_SCRIPT
set -euo pipefail
export PATH="$$HOME/.local/bin:$$PATH"

desired="$${LAZYGIT_VERSION}"              # e.g. v0.44.1
stripped="$${desired#v}"                    # release tarballs drop the leading v
if command -v lazygit >/dev/null 2>&1; then
	current="$$(lazygit --version 2>/dev/null | tr ',' '\n' | awk -F= '$$1 ~ /^[[:space:]]*version$$/ {gsub(/^[[:space:]]+/, "", $$2); print $$2; exit}')"
	if [[ "v$$current" == "$$desired" || "$$current" == "$$desired" ]]; then
		echo "lazygit $$desired already installed"
		exit 0
	fi
fi

work_dir="$$HOME/.cache/lazygit-install-$${desired}"
tarball="$$work_dir/lazygit.tar.gz"
release_url="https://github.com/jesseduffield/lazygit/releases/download/$${desired}/lazygit_$${stripped}_Linux_x86_64.tar.gz"
install_dir="$$HOME/.local/opt/lazygit-$${desired}"

mkdir -p "$$HOME/.local/bin" "$$HOME/.local/opt" "$$work_dir"

curl -fL --retry 3 --retry-delay 2 -o "$$tarball" "$$release_url"
rm -rf "$$install_dir"
mkdir -p "$$install_dir"
tar -xzf "$$tarball" -C "$$install_dir" lazygit
ln -sf "$$install_dir/lazygit" "$$HOME/.local/bin/lazygit"
installed="$$("$$HOME/.local/bin/lazygit" --version 2>/dev/null | tr ',' '\n' | awk -F= '$$1 ~ /^[[:space:]]*version$$/ {gsub(/^[[:space:]]+/, "", $$2); print $$2; exit}')"
if [[ "v$$installed" != "$$desired" && "$$installed" != "$$desired" ]]; then
	echo "lazygit install verification failed: got '$$installed', expected '$$desired'" >&2
	exit 1
fi
echo "Installed lazygit $$desired from GitHub release tarball"
endef
export LAZYGIT_INSTALL_SCRIPT

define NVIM_WARMUP_SCRIPT
set -e
export PATH="$$HOME/.local/bin:$$PATH"
export NVIM_REMOTE_SERVER=1

if ! command -v nvim >/dev/null 2>&1; then
	echo "nvim not on PATH, skipping warmup"
	exit 0
fi

# Clean any AppleDouble cruft from macOS-originated rsync.
if [[ -d "$$HOME/.config/nvim" ]]; then
	find "$$HOME/.config/nvim" -type f -name "._*" -delete 2>/dev/null || true
	find "$$HOME/.config/nvim" -type d -name "__MACOSX" -prune -exec rm -rf {} + 2>/dev/null || true
fi

mkdir -p "$$HOME/.cache"
lock="$$HOME/.cache/nvim-warmup.lock"
log="$$HOME/.cache/nvim-warmup.log"

if [[ -f "$$lock" ]] && kill -0 "$$(cat "$$lock" 2>/dev/null)" 2>/dev/null; then
	echo "nvim warmup already running (pid $$(cat "$$lock"))"
	exit 0
fi

nohup bash -lc "
	export PATH=\"\$$HOME/.local/bin:\$$PATH\"
	export NVIM_REMOTE_SERVER=1
	nvim --headless '+Lazy! restore' +qa || true
	nvim --headless '+TSInstallSync bash c cpp go html javascript json lua markdown python query rust tsx typescript vim vimdoc yaml' +qa || true
	nvim --headless '+MasonToolsInstallSync' +qa || true
	nvim --headless +qa || true
	rm -f \"$$lock\"
" > "$$log" 2>&1 < /dev/null &
echo "$$!" > "$$lock"
echo "Started nvim warmup in background (log: $$log)"
endef
export NVIM_WARMUP_SCRIPT
