# =====================================
# General
# =====================================

# zsh-completions plugin
fpath=($ZDOTDIR/plugins/zsh-completions/src $fpath)

# Ensure completions directory exists
mkdir -p $ZDOTDIR/completions

# fnm completions
[ ! -f "$ZDOTDIR/completions/_fnm" ] && fnm completions --shell=zsh > $ZDOTDIR/completions/_fnm
fpath+="$ZDOTDIR/completions/_fnm"

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
zstyle ':completion:*:(ssh|scp|rsync):*' hosts \
    $(awk '{print $1}' ~/.ssh/known_hosts | cut -d, -f1 | sort -u)

# =====================================
# Additional
# =====================================

# pnpm completions – must be sourced after compinit
[ ! -f "$ZDOTDIR/completions/_pnpm" ] && pnpm completion zsh > $ZDOTDIR/completions/_pnpm
source $ZDOTDIR/completions/_pnpm
