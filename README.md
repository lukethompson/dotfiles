# Luke Thompson's dotfiles

My personal dotfiles, built primarily for macOS, with support for a headless Debian dev machine.

## What's included

### Shared

- **Shell:** zsh with the [Pure](https://github.com/sindresorhus/pure/) prompt, shell aliases,
  [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions),
  [zsh-completions](https://github.com/zsh-users/zsh-completions), and
  [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting).
- **Git:** Shared defaults and a global gitignore.

### macOS

- **[Ghostty](https://ghostty.org/) configuration.**
- **Apps and tools:** [Homebrew](https://brew.sh/) packages listed in the [Brewfile](Brewfile).

### Debian

- **Containers:** Rootless Docker and Compose.
- **Developer tools:** CLI packages and tools listed in [bootstrap.sh](bootstrap.sh).

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
