# =====================================
# Prompt
# =====================================

fpath+=($ZDOTDIR/prompt)
autoload -U promptinit; promptinit
prompt pure

# =====================================
# Tools
# =====================================

# Fast Node Manager
eval "$(fnm env --use-on-cd --shell zsh)"

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
