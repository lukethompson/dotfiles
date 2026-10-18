# Keep only the first copy of each PATH entry. A nested login shell (herdr
# pane, zsh -l) inherits PATH, then brew shellenv and the re-adds below add
# the same directories again.
typeset -U path PATH

# Homebrew (Apple Silicon)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# On macOS, path_helper (run by /etc/zprofile) and brew shellenv push the
# entries ~/.zshenv added behind the system and Homebrew directories. Put them
# back in front; typeset -U drops the later duplicate. This keeps fnm's default
# Node ahead of Homebrew's node in zsh -lc; .zshrc puts the per-directory
# version ahead of both.
path=("$HOME/.local/bin" ${FNM_DIR:+"$FNM_DIR/aliases/default/bin"} $path)

# pnpm's global binaries go last, so a stale copy there never shadows a tool
# installed by Homebrew or bootstrap.sh.
path+=(${PNPM_HOME:+"$PNPM_HOME/bin"})

# OrbStack - command-line tools and integration
if [[ -r ~/.orbstack/shell/init.zsh ]]; then
  source ~/.orbstack/shell/init.zsh
fi
