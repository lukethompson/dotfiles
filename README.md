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
- [Homebrew](https://brew.sh/) package manager for macOS, plus the tools and packages I use — check out
  the [Brewfile](https://github.com/lukethompson/dotfiles/blob/main/Brewfile)

## Supported systems
- Apple Silicon macOS
- Debian 13 or later on amd64 or arm64

## Installation

```bash
# Debian only: a fresh install has no git yet
sudo apt install git
# Clone the repository
git clone https://github.com/lukethompson/dotfiles.git
cd dotfiles
# Optional: see what a run would change first
./bootstrap.sh --check
# Bootstrap the machine
./bootstrap.sh
```

`bootstrap.sh` is idempotent — it skips anything already installed, so it is safe to
re-run. It doesn't upgrade installed packages. On both platforms it links the dotfiles and offers
to set a git identity, a GitHub SSH key and the GitHub CLI login. It ends with a summary of every
step, and exits non-zero if any step failed.

Run it as your own user, not root.

### macOS
Installs the Command Line Tools, Homebrew, the Brewfile and Node. Upgrade with `brew upgrade`;
Claude Code updates itself.

### Debian
Asks for `sudo` only when something system-wide is missing (packages, the terminfo entry, the
login shell), and installs:

| Tool | From | Update with |
| --- | --- | --- |
| zsh, git, gh, fzf, lazygit, ripgrep, fd, jq, stow, nano, build tools | apt (`APT_PACKAGES` in `bootstrap.sh`) | `sudo apt upgrade` |
| `xterm-ghostty` terminfo | copied from ncurses-term's `ghostty` entry into `/etc/terminfo` | — |
| fnm | official installer → `~/.local/bin` | `curl -fsSL https://fnm.vercel.app/install \| bash -s -- --install-dir ~/.local/bin --skip-shell` |
| Node | latest LTS, through fnm | `fnm install --lts` |
| pnpm | official standalone installer → `$PNPM_HOME/bin` | `pnpm self-update` |
| herdr | official installer → `~/.local/bin` | `herdr update` |
| Claude Code | native installer, latest channel | updates itself |
| Codex | official standalone installer → `~/.local/bin` | re-run the installer |
| OpenCode v2 | official installer → `~/.opencode/bin`, linked into `~/.local/bin` | re-run the installer |

## Local files
You can add untracked local files to provide some machine-specific customizations. Currently the
following files are supported:
- `~/.config/aliases/local`
- `~/.config/zsh/.zshrc.local`
- `~/.gitconfig` — your git identity, written by `bootstrap.sh`
