# XDG
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$XDG_CONFIG_HOME/local/share"
export XDG_CACHE_HOME="$XDG_CONFIG_HOME/cache"

# Editor
export EDITOR="code"
export VISUAL="code"

# zsh
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export HISTFILE="$ZDOTDIR/.zhistory" # History filepath
export HISTSIZE=50000 # Maximum events for internal history
export SAVEHIST=50000 # Maximum events in history file
