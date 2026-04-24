# Login shells read this file. Delegate to .bashrc so interactive login and
# interactive non-login shells behave the same (the fish handoff lives there).
[ -f ~/.bashrc ] && . ~/.bashrc
