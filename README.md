# Luke Thompson's dotfiles

My personal dotfiles for MacOS.

## What's included
- Opinionated zsh configuration with the following plugins:
  - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
  - [zsh-completions](https://github.com/zsh-users/zsh-completions)
  - [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [Pure](https://github.com/sindresorhus/pure/) prompt
- Git configuration, including a global gitignore
- [Ghostty](https://ghostty.org/) configuration
- [Homebrew](https://brew.sh/) package manager for MacOS, plus the tools and packages I use — check out
  the [Brewfile](https://github.com/lukethompson/dotfiles/blob/main/Brewfile)

## Installation

```bash
# Clone the repository into your home directory
git clone https://github.com/lukethompson/dotfiles.git
cd dotfiles
# Bootstrap the machine: submodules, Homebrew, symlinks, git identity, GitHub SSH key,
# Brewfile packages and Node.
./bootstrap.sh
```

`bootstrap.sh` is idempotent — it skips anything already installed, so it is safe to
re-run after updating the Brewfile. It doesn't upgrade installed packages; run
`brew upgrade` for that.

## Local files
You can add untracked local files to provide some machine-specific customizations. Currently the following files are supported:
- `~/.config/aliases/local`
- `~/.config/zsh/.zshrc.local`
- `~/.gitconfig` — your git identity, written by `bootstrap.sh`
