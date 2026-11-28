# Keep the first copy of each PATH entry in nested login shells.
typeset -U path PATH

# Homebrew (Apple Silicon)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Restore ~/.local/bin precedence after path_helper and brew shellenv.
path=("$HOME/.local/bin" $path)

# OrbStack - command-line tools and integration
if [[ -r ~/.orbstack/shell/init.zsh ]]; then
  source ~/.orbstack/shell/init.zsh
fi
