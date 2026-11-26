# Luke Thompson's dotfiles

My personal dotfiles, built mainly for macOS, with support for a slimmed-down Debian dev machine.

## What's included
- Opinionated zsh configuration with the following plugins:
  - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
  - [zsh-completions](https://github.com/zsh-users/zsh-completions)
  - [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [Pure](https://github.com/sindresorhus/pure/) prompt
- Git configuration, including a global gitignore
- [Ghostty](https://ghostty.org/) configuration
- [Homebrew](https://brew.sh/) packages for macOS, listed in the [Brewfile](Brewfile)

## Supported systems
- Apple Silicon macOS
- Debian 13 or later on amd64 or arm64

## Installation

### Debian prerequisite

If Git isn't installed yet:

```bash
sudo apt install git
```

### Bootstrap on either platform

```bash
git clone https://github.com/lukethompson/dotfiles.git
cd dotfiles
# Optional: see what a run would change first
./bootstrap.sh --check
# Bootstrap the machine
./bootstrap.sh
```

Run `bootstrap.sh` as your own user, not root. You can re-run it to install missing packages
without upgrading existing ones.

Before linking the dotfiles, bootstrap moves conflicting files to timestamped backups. It offers
to set up your Git identity, a GitHub SSH key, and GitHub CLI login. It prints a summary at the end
and exits non-zero if any step failed.

Open a new terminal after setup to load the new configuration.

### macOS

Bootstrap installs the packages and apps listed in the [Brewfile](Brewfile) and the latest LTS
version of Node through fnm. Use `brew upgrade` to update Homebrew packages and `fnm install --lts`
to install a newer Node LTS. Claude Code can update itself.

### Debian
Asks for `sudo` only when something system-wide is missing (packages, the terminfo entry, the
login shell, the Docker setup), and installs:

| Tool | From | Update with |
| --- | --- | --- |
| Debian packages | apt (see `APT_PACKAGES` in [bootstrap.sh](bootstrap.sh)) | `sudo apt upgrade` |
| Docker Engine, Compose, buildx | Docker's apt repo, run rootless | `sudo apt upgrade` |
| `xterm-ghostty` terminfo | copied from ncurses-term's `ghostty` entry into `/etc/terminfo` | — |
| fnm | official installer → `~/.local/bin` | re-run the [official installer](https://github.com/Schniz/fnm#using-a-script-macoslinux) with `--install-dir ~/.local/bin --skip-shell` |
| Node | latest LTS, through fnm | `fnm install --lts` |
| pnpm | official standalone installer → `$PNPM_HOME/bin` | `pnpm self-update` |
| herdr | official installer → `~/.local/bin` | `herdr update` |
| Claude Code | native installer, latest channel | updates itself |
| Codex | official standalone installer → `~/.local/bin` | re-run the installer |
| OpenCode v2 | official installer → `~/.opencode/bin`, linked into `~/.local/bin` | re-run the installer |

Bootstrap stops and disables the system Docker daemon when setting up rootless Docker. The rootless
daemon runs as your user, so `docker` and `docker compose` don't need `sudo` or membership in the
root-equivalent `docker` group.

## Local files
Machine-specific settings go in these untracked files:
- `~/.config/aliases/local`
- `~/.config/zsh/.zshrc.local`
- `~/.gitconfig` — your git identity, written by `bootstrap.sh`
