# notion-dotfiles

ehong's dotfiles for Notion boxy dev environments (Debian bullseye).

## Quickstart

From your laptop:

```sh
BOXY=your--boxy-name
scp init.sh $BOXY.boxy.makenotion.com:/tmp/init.sh
ssh $BOXY.boxy.makenotion.com "bash /tmp/init.sh && rm /tmp/init.sh"
```

Runs as `notion` (not root) so that `GH_TOKEN` is available for `gh repo clone`
on this private repo; the script uses `sudo` inline for apt. That clones the
repo to `/home/notion/notion-dotfiles`, runs `make all`, and you're done.

## What's in here

- `Makefile` — all setup logic; `make help` lists targets
- `init.sh` — boxy bootstrap: apt + sudo, then hands off to `make all` as `notion`
- `home/` — mirrors `$HOME`; every file is symlinked into place by `make symlinks`

## Targets

| target     | does                                                            |
|------------|-----------------------------------------------------------------|
| `all`      | `deps` → `fish` → `symlinks` → `nvim` → `warmup`                |
| `deps`     | apt: git, curl, ripgrep, fd-find, build-essential, tar          |
| `fish`     | apt install fish + `chsh` to fish for `$USER`                   |
| `symlinks` | mirror `home/` into `$HOME` as symlinks (backs up non-symlinks) |
| `nvim`     | install Neovim v0.11.2 (tarball, then source fallback)          |
| `warmup`   | background: `Lazy! restore`, `TSInstallSync`, Mason             |
| `clean`    | remove symlinks created by `symlinks` (`.bak` files untouched)  |

## Iteration

Edit a config locally, push, then on the boxy:

```sh
cd ~/notion-dotfiles && git pull
```

Symlinks mean the change is live — no re-run needed unless you changed `Makefile` or added a new dotfile (then `make symlinks`).
