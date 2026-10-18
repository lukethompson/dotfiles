# XDG
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$XDG_CONFIG_HOME/local/share"
export XDG_CACHE_HOME="$XDG_CONFIG_HOME/cache"

# Editor. .zshrc switches interactive shells to VS Code where it can open.
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

# fnm's Node versions and pnpm's global binaries. Set here so PATH below can
# use them without running fnm; bootstrap.sh sets the same values.
if [[ $OSTYPE == darwin* ]]; then
  export FNM_DIR="$HOME/Library/Application Support/fnm"
else
  export FNM_DIR="$XDG_DATA_HOME/fnm"
fi
export PNPM_HOME="$XDG_DATA_HOME/pnpm"

# Lets a Homebrew-installed Claude Code upgrade its own cask. The native
# install updates itself and ignores this.
export CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1

# Path. Set here, not only in .zprofile, so commands run over SSH
# (ssh host 'node -v') find Node and pnpm. That shell is neither login nor
# interactive, so this is the only dotfile it reads.
path=("$HOME/.local/bin" "$FNM_DIR/aliases/default/bin" $path "$PNPM_HOME/bin")
