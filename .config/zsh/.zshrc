# =====================================
# Environment
# =====================================

# VS Code as the editor wherever it can open the file. In VS Code's or
# code-server's own terminal, even over SSH, it opens in that window;
# code-server's terminal has code-server, not code. Elsewhere only outside SSH,
# and on Linux only in a desktop session. Checked here because Homebrew's code
# isn't on PATH in ~/.zshenv. --wait makes git wait for the file to be closed.
() {
  local editor
  if [[ $TERM_PROGRAM == vscode ]]; then
    if (( $+commands[code] )); then
      editor=code
    elif (( $+commands[code-server] )); then
      editor=code-server
    fi
  elif (( $+commands[code] )) && [[ -z $SSH_CONNECTION ]] &&
       [[ $OSTYPE == darwin* || -n $DISPLAY || -n $WAYLAND_DISPLAY ]]; then
    editor=code
  fi
  if [[ -n $editor ]]; then
    export EDITOR="$editor --wait"
    export VISUAL="$editor --wait"
  fi
}

# =====================================
# Prompt
# =====================================

fpath+=($ZDOTDIR/prompt)
autoload -U promptinit; promptinit
prompt pure

# =====================================
# Tools
# =====================================

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
