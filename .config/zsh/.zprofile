# Unique, so nested login shells (herdr panes, zsh -l) do not duplicate the
# entries brew shellenv prepends again. ~/.zshenv is no help here: a nested
# shell inherits ZDOTDIR and so never reads it.
typeset -U path PATH

# Homebrew (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"

# /etc/zprofile runs path_helper, which moves the ~/.local/bin that ~/.zshenv
# prepended behind the system directories. Put it back in front; typeset -U
# drops the later duplicate.
path=("$HOME/.local/bin" $path)

# OrbStack - command-line tools and integration
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
