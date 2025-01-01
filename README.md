# Luke Thompson's dotfiles

My personal dotfiles for MacOS.

## Requirements

> **Note:** A script will be added in future to install the following dependencies and bootstrap a new machine.

- [GNU Stow](https://www.gnu.org/software/stow/) – Symlink Farm Manager
- [Homebrew](https://brew.sh/) - Package Manager for MacOS
- [Zsh](https://www.zsh.org/) - Shell
- [fnm](https://github.com/Schniz/fnm) - Fast Node Manager

## What's included
- Opinionated zsh configuration with the following plugins:
  - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
  - [zsh-completions](https://github.com/zsh-users/zsh-completions)
  - [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [Pure](https://github.com/sindresorhus/pure/) prompt
- Git configuration
- [Ghostty](https://ghostty.org/) configuration

## Installation

```bash
# Clone the repository and submodules into your home directory
git clone --recurse-submodules https://github.com/lukethompson/dotfiles.git
# Within the dotfiles directory, run stow to symlink the dotfiles
cd dotfiles
stow .
```

## Local files
You can add local files to the symlinked `~/.config` directory to provide some local customizations. Currently the following files are supported:
- `~/.config/aliases/local`
- `~/.config/zsh/.zshrc.local`

