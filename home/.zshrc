# Preserve any boxy-injected defaults that were backed up when this symlink
# first replaced the stock file (e.g. env vars or path tweaks).
[ -f ~/.zshrc.bak ] && . ~/.zshrc.bak

# Mirror of ~/.bashrc: hand off to fish for interactive shells only. Boxies
# default the notion user's login shell to zsh, so without this the .bashrc
# handoff never fires and interactive SSH lands in zsh instead of fish.
case $- in
	*i*)
		if command -v fish >/dev/null 2>&1 && [ -z "${__FISH_EXEC:-}" ]; then
			export __FISH_EXEC=1
			exec fish
		fi
		;;
esac
