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

Bootstrap backs up conflicting files before linking the dotfiles.

Open a new terminal after setup to load the new configuration.

### macOS

Mac apps and tools are listed in the [Brewfile](Brewfile). Update them with `brew upgrade`.
Node is managed separately with [fnm](https://github.com/Schniz/fnm).

### Debian

The package list is in [bootstrap.sh](bootstrap.sh). Update apt packages with `sudo apt upgrade`.

Bootstrap stops and disables the system Docker daemon when setting up rootless Docker.
After that, `docker` and `docker compose` run without `sudo`.

## Local files
Machine-specific settings go in these untracked files:
- `~/.config/aliases/local`
- `~/.config/zsh/.zshrc.local`
- `~/.gitconfig` — your git identity, written by `bootstrap.sh`
