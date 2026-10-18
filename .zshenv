# XDG
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$XDG_CONFIG_HOME/local/share"
export XDG_CACHE_HOME="$XDG_CONFIG_HOME/cache"

# Editor. VS Code only at the Mac's own screen: over SSH it would open on a
# display nobody is looking at. --wait keeps git from reading an empty message
# while the file is still open.
if [[ $OSTYPE == darwin* && -z $SSH_CONNECTION ]]; then
  export EDITOR="code --wait"
  export VISUAL="code --wait"
else
  export EDITOR="nano"
  export VISUAL="nano"
fi

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

# Path
export PATH="$HOME/.local/bin:$PATH"
