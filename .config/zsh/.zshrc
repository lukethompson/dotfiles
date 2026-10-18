# =====================================
# Prompt
# =====================================

fpath+=($ZDOTDIR/prompt)
autoload -U promptinit; promptinit
prompt pure

# =====================================
# Tools
# =====================================

# Editor - VS Code if installed, outside SSH, and on Linux only in a desktop
# session. Checked here because Homebrew's code isn't on PATH in ~/.zshenv.
# --wait makes git wait for the file to be closed.
if (( $+commands[code] )) && [[ -z $SSH_CONNECTION ]] &&
   [[ $OSTYPE == darwin* || -n $DISPLAY || -n $WAYLAND_DISPLAY ]]; then
  export EDITOR="code --wait"
  export VISUAL="code --wait"
fi
# fnm - Fast Node Manager
if (( $+commands[fnm] )); then
  path=(${path:#*/fnm_multishells/*}) # drop inherited multishell dirs; fnm env adds a fresh one
  eval "$(fnm env --use-on-cd --shell zsh)"
fi
# fzf - command line fuzzy finder
if (( $+commands[fzf] )); then
  source <(fzf --zsh)
fi

# =====================================
# Aliases
# =====================================

source "$XDG_CONFIG_HOME/aliases/base"

# =====================================
# Completions
# =====================================

source "$ZDOTDIR/completions.zsh"

# =====================================
# Plugins
# =====================================

source "$ZDOTDIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
source "$ZDOTDIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"

# =====================================
# Optional local files
# =====================================

source "$XDG_CONFIG_HOME/aliases/local" 2> /dev/null
source "$ZDOTDIR/.zshrc.local" 2> /dev/null
