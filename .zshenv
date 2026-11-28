# XDG
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$XDG_CONFIG_HOME/local/share"
export XDG_CACHE_HOME="$XDG_CONFIG_HOME/cache"

# --wait lets Git wait for the editor tab to close.
if [[ $OSTYPE == darwin* ]]; then
  export EDITOR="code --wait"
else
  export EDITOR="nano"
fi
export VISUAL="$EDITOR"

# zsh
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export HISTFILE="$ZDOTDIR/.zhistory" # History filepath
export HISTSIZE=50000 # Maximum events for internal history
export SAVEHIST=50000 # Maximum events in history file
# completions.zsh runs compinit; skip the one in Debian's /etc/zsh/zshrc.
# Exported so nested shells, which never read this file, skip it too.
export skip_global_compinit=1

export PNPM_HOME="$XDG_DATA_HOME/pnpm"

# Lets a Homebrew-installed Claude Code upgrade its own cask.
export CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1

# Put pnpm last so its global binaries don't shadow other installs.
path=("$HOME/.local/bin" $path "$PNPM_HOME/bin")
