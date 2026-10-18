# Unique, so nested login shells (herdr panes, zsh -l) do not duplicate the
# entries brew shellenv prepends again. ~/.zshenv is no help here: a nested
# shell inherits ZDOTDIR and so never reads it.
typeset -U path PATH

# Homebrew (Apple Silicon)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# On macOS, /etc/zprofile runs path_helper, which moves the entries ~/.zshenv
# prepended behind the system directories, and brew shellenv then puts
# Homebrew ahead of them. Put them back in front; typeset -U drops the later
# duplicate.
#
# fnm's default Node comes after ~/.local/bin, so login shells that never run
# .zshrc (zsh -lc) find it ahead of Homebrew's node. Interactive shells put
# fnm env's per-shell version ahead of it.
path=("$HOME/.local/bin" ${FNM_DIR:+"$FNM_DIR/aliases/default/bin"} $path)

# pnpm's global binaries go last, so a stale copy there never shadows the pnpm
# or tools installed by Homebrew or bootstrap.sh.
path+=(${PNPM_HOME:+"$PNPM_HOME/bin"})

# OrbStack - command-line tools and integration
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
