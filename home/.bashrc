# Preserve any boxy-injected defaults that were backed up when this symlink
# first replaced the stock file (e.g. env vars like GH_TOKEN).
[ -f ~/.bashrc.bak ] && . ~/.bashrc.bak

# Hand off to fish only for interactive shells. Leaving bash as the login shell
# keeps non-interactive SSH commands (notion-next's remote-shell probe runs
# `exec "$(getent passwd "$USER" | cut -d: -f7)" -lc true`, which fish can't
# parse) working.
case $- in
	*i*)
		if command -v fish >/dev/null 2>&1 && [ -z "${__FISH_EXEC:-}" ]; then
			export __FISH_EXEC=1
			exec fish
		fi
		;;
esac
