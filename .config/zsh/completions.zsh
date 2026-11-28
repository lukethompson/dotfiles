# Inspired by https://github.com/Phantas0s/.dotfiles/blob/master/zsh/completion.zsh

# =====================================
# General
# =====================================

fpath=($ZDOTDIR/plugins/zsh-completions/src $fpath)

# Add generated completions to fpath before compinit scans it.
mkdir -p $ZDOTDIR/completions
fpath+=($ZDOTDIR/completions)

# Generate _fnm only if it's missing or empty.
if (( $+commands[fnm] )) && [[ ! -s $ZDOTDIR/completions/_fnm ]]; then
  fnm completions --shell=zsh >| $ZDOTDIR/completions/_fnm
fi

autoload -Uz compinit; compinit

# =====================================
# Options
# =====================================

setopt AUTO_LIST # List choices when there's more than one match
setopt COMPLETE_IN_WORD # Complete from both ends of a word
setopt globdots # Show dotfiles in completion menu
setopt MENU_COMPLETE # Insert the first match and cycle with Tab

# =====================================
# zstyles
# =====================================

# Completion context:
# :completion:<function>:<completer>:<command>:<argument>:<tag>

# Try filename extensions and standard matches before allowing typos.
zstyle ':completion:*' completer _extensions _complete _approximate

# Cache results for completers that support it.
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"

# Navigate matches with arrow keys.
zstyle ':completion:*' menu select

# Offer cd flags as well as directory stack entries.
zstyle ':completion:*' complete-options true

# Color-code completion messages.
zstyle ':completion:*:*:*:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:*:*:*:descriptions' format '%F{blue}-- %D %d --%f'
zstyle ':completion:*:*:*:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:*:*:*:warnings' format ' %F{red}-- no matches found --%f'

# Group matches by type and order the command groups.
zstyle ':completion:*' group-name ''
zstyle ':completion:*:*:-command-:*:*' group-order aliases builtins functions commands

zstyle ':completion:*' use-ip true
# Complete SSH hosts from known_hosts; skip hashes, markers, and comments,
# then take the first host per entry and strip any [host]:port wrapper.
if [[ -r ~/.ssh/known_hosts ]]; then
  zstyle ':completion:*:(ssh|scp|rsync):*' hosts \
      $(awk '$1 !~ /^[|@#]/ {print $1}' ~/.ssh/known_hosts | cut -d, -f1 |
        sed -E 's/^\[([^]]+)\]:[0-9]+$/\1/' | sort -u)
fi

# =====================================
# Additional
# =====================================

# Source pnpm's generated script after compinit so it can call compdef.
if (( $+commands[pnpm] )) && [[ ! -s $ZDOTDIR/completions/_pnpm ]]; then
  pnpm completion zsh >| $ZDOTDIR/completions/_pnpm
fi
if [[ -s $ZDOTDIR/completions/_pnpm ]]; then
  source $ZDOTDIR/completions/_pnpm
fi
