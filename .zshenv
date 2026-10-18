# XDG
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$XDG_CONFIG_HOME/local/share"
export XDG_CACHE_HOME="$XDG_CONFIG_HOME/cache"

# Editor. nano for shells that never read .zshrc (zsh -c, ssh host cmd);
# .zshrc switches interactive shells to VS Code when there is a screen for it.
export EDITOR="nano"
export VISUAL="nano"

# zsh
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export HISTFILE="$ZDOTDIR/.zhistory" # History filepath
export HISTSIZE=50000 # Maximum events for internal history
export SAVEHIST=50000 # Maximum events in history file
# completions.zsh runs compinit; skip the one in Debian's /etc/zsh/zshrc.
# Exported so nested shells, which never read this file, skip it too.
export skip_global_compinit=1

# Node and pnpm. Set explicitly so bootstrap.sh, login shells and fnm agree on
# where Node versions and pnpm's global binaries live.
if [[ $OSTYPE == darwin* ]]; then
  export FNM_DIR="$HOME/Library/Application Support/fnm"
else
  export FNM_DIR="$XDG_DATA_HOME/fnm"
fi
export PNPM_HOME="$XDG_DATA_HOME/pnpm"

# Homebrew installs of Claude Code don't update themselves; this lets Claude
# Code run brew upgrade for its own cask. No effect on the native install.
export CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1

# Path. Set here so commands run over SSH (ssh host 'node -v'), which start a
# shell that is neither login nor interactive, still find user tools, fnm's
# default Node and pnpm. .zprofile re-adds them for login shells.
path=("$HOME/.local/bin" "$FNM_DIR/aliases/default/bin" $path "$PNPM_HOME/bin")
