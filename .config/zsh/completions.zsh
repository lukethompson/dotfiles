# Inspired by https://github.com/Phantas0s/.dotfiles/blob/master/zsh/completion.zsh

# =====================================
# General
# =====================================

# zsh-completions plugin
fpath=($ZDOTDIR/plugins/zsh-completions/src $fpath)

# Ensure completions directory exists
mkdir -p $ZDOTDIR/completions

# Generated completions are cached here. Each is written only when its tool is
# installed, and regenerated if an earlier attempt left the file empty.
fpath+=($ZDOTDIR/completions)

# fnm completions
if (( $+commands[fnm] )) && [[ ! -s $ZDOTDIR/completions/_fnm ]]; then
  fnm completions --shell=zsh >| $ZDOTDIR/completions/_fnm
fi

# Load and initialize zsh completions
autoload -Uz compinit; compinit

# =====================================
# Options
# =====================================

setopt AUTO_LIST # Automatically list choices on ambiguous completion
setopt COMPLETE_IN_WORD # Complete from both ends of a word
setopt globdots # Show dotfiles in completion menu
setopt MENU_COMPLETE # Automatically highlight first element of completion menu

# =====================================
# zstyles
# =====================================

# Ztyle pattern
# :completion:<function>:<completer>:<command>:<argument>:<tag>

# Define completers
zstyle ':completion:*' completer _extensions _complete _approximate

# Use cache for commands using cache
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"

# Highlight selection
zstyle ':completion:*' menu select

# Autocomplete options for cd instead of directory stack
zstyle ':completion:*' complete-options true

# Improve completion messages
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:*:*:*:descriptions' format '%F{blue}-- %D %d --%f'
zstyle ':completion:*:*:*:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:*:*:*:warnings' format ' %F{red}-- no matches found --%f'

# Improve completion groups
zstyle ':completion:*' group-name ''
zstyle ':completion:*:*:-command-:*:*' group-order aliases builtins functions commands

# Improve completion hosts
zstyle ':completion:*' use-ip true
if [[ -r ~/.ssh/known_hosts ]]; then
  zstyle ':completion:*:(ssh|scp|rsync):*' hosts \
      $(awk '{print $1}' ~/.ssh/known_hosts | cut -d, -f1 | sort -u)
fi

# =====================================
# Additional
# =====================================

# pnpm completions – must be sourced after compinit
if (( $+commands[pnpm] )) && [[ ! -s $ZDOTDIR/completions/_pnpm ]]; then
  pnpm completion zsh >| $ZDOTDIR/completions/_pnpm
fi
if [[ -s $ZDOTDIR/completions/_pnpm ]]; then
  source $ZDOTDIR/completions/_pnpm
fi
