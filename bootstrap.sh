#!/bin/bash

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NOCOLOR='\033[0m'
RED='\033[0;31m'

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Same value .zshenv sets, which isn't linked yet on a fresh machine. brew trust
# saves under this path, so without it later shells wouldn't see the trust.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

CHECK_MODE=false
BUNDLE_FAILED=false
SSH_KEY_CREATED=false
STOW_CONFLICTS=()
STOW_ERROR=""

# Directories apps write to at runtime (zsh history, compdump), relative to the
# target. They must exist before stowing, or stow replaces each with a single
# symlink and those writes land in the repo.
REAL_DIRS=(.config .config/zsh)

info() { echo -e "${BLUE}$1${NOCOLOR}"; }
success() { echo -e "${GREEN}$1${NOCOLOR}"; }
error() { echo -e "${RED}$1${NOCOLOR}" >&2; }

# Moves a path to a timestamped backup and prints the new path. The counter
# stops two backups in the same second from overwriting each other.
backup_path() {
  local path="$1"
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  local backup="$path.bak.$stamp"
  local suffix=1

  while [ -e "$backup" ]; do
    backup="$path.bak.$stamp-$suffix"
    suffix=$((suffix + 1))
  done

  mv "$path" "$backup"
  echo "$backup"
}

# Fills STOW_CONFLICTS with the paths stow would refuse to overwrite. A dry
# run (--no) lists them all at once. Stow phrases conflicts two ways, so match
# both. Any other failure returns 1 and leaves stow's output in STOW_ERROR.
detect_stow_conflicts() {
  local target="$1"
  local output=""
  local path

  STOW_CONFLICTS=()
  STOW_ERROR=""

  # Inside the if so a non-zero exit doesn't trip set -e.
  if output="$(stow --dir="$DOTFILES_DIR" --target="$target" --restow --no . 2>&1 >/dev/null)"; then
    return 0
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    STOW_CONFLICTS[${#STOW_CONFLICTS[@]}]="$target/$path"
  done <<EOF
$(printf '%s\n' "$output" | sed -n \
  -e 's/.*over existing target \(.*\) since.*/\1/p' \
  -e 's/.*existing target is not owned by stow: \(.*\)/\1/p')
EOF

  if [ "${#STOW_CONFLICTS[@]}" -eq 0 ]; then
    STOW_ERROR="$output"
    return 1
  fi
}

detect_stow_conflicts_or_exit() {
  if ! detect_stow_conflicts "$1"; then
    error "stow failed for a reason other than a file conflict:"
    error "$STOW_ERROR"
    exit 1
  fi
}

require_apple_silicon_macos() {
  if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
    error "These dotfiles only support Apple Silicon MacOS."
    exit 1
  fi
}

# git ships with the Command Line Tools. xcode-select --install only opens an
# installer window and returns, so stop and ask for a re-run.
require_command_line_tools() {
  info "Checking for Command Line Tools..."
  if xcode-select -p &>/dev/null; then
    success "Command Line Tools are installed"
    return
  fi

  xcode-select --install
  error "Command Line Tools are not installed. Finish the installer that just opened, then re-run this script."
  exit 1
}

init_submodules() {
  info "Fetching zsh plugins and prompt..."
  git -C "$DOTFILES_DIR" submodule update --init --recursive
  success "Submodules ready"
}

install_homebrew() {
  info "Checking for Homebrew..."
  # Look for the binary itself. brew isn't on PATH until .zprofile runs, so
  # `command -v brew` would miss an existing install and reinstall it.
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    success "Homebrew is already installed"
    return
  fi

  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  eval "$(/opt/homebrew/bin/brew shellenv)"

  if ! command -v brew &>/dev/null; then
    error "Homebrew installation failed: brew not found on PATH"
    exit 1
  fi

  success "Homebrew installation complete"
}

# stow links the dotfiles and fnm installs Node. Install them on their own so
# a failed Brewfile entry can't leave either one missing.
install_required_packages() {
  info "Installing stow and fnm..."
  brew install stow fnm
  success "stow and fnm installed"
}

ensure_real_dirs() {
  local target="$1"
  local dir

  for dir in "${REAL_DIRS[@]}"; do
    # An earlier run linked this whole directory to the repo. Deleting the
    # symlink isn't enough: files apps wrote through it are in the repo now and
    # would be linked straight back.
    if [ -L "$target/$dir" ]; then
      error "$target/$dir is a symlink, so writes to it land in the repo."
      error "Unstow with: stow --dir=\"$DOTFILES_DIR\" --target=\"$target\" -D ."
      error "Move any untracked runtime files out of $DOTFILES_DIR/$dir, then re-run."
      exit 1
    fi
    mkdir -p "$target/$dir"
  done
}

# One real file where a symlink should go makes stow abort everything. Apps
# opened before bootstrapping (e.g. Ghostty) leave these behind, so back them
# up without asking.
resolve_stow_conflicts() {
  local target="$1"
  local path
  local backup

  info "Checking for files that would block symlinking..."
  detect_stow_conflicts_or_exit "$target"

  if [ "${#STOW_CONFLICTS[@]}" -eq 0 ]; then
    success "No conflicting files found"
    return
  fi

  for path in "${STOW_CONFLICTS[@]}"; do
    echo "Backing up $path"
    backup="$(backup_path "$path")"
    success "Backup complete: $backup created"
  done

  # Check once more instead of looping: anything left is a conflict the parser
  # doesn't recognise, so name it rather than let stow abort.
  detect_stow_conflicts_or_exit "$target"
  if [ "${#STOW_CONFLICTS[@]}" -ne 0 ]; then
    error "Files still block symlinking after backing up:"
    for path in "${STOW_CONFLICTS[@]}"; do
      error "  $path"
    done
    exit 1
  fi
}

stow_dotfiles() {
  local target="${1:-$HOME}"

  ensure_real_dirs "$target"
  resolve_stow_conflicts "$target"

  info "Symlinking dotfiles into $target..."
  stow --dir="$DOTFILES_DIR" --target="$target" --restow .
  success "Dotfiles symlinked"
}

# The identity goes in ~/.gitconfig, which git reads after ~/.config/git/config.
# The file must exist even without one: otherwise git config --global writes
# to ~/.config/git/config, which is a symlink into the repo.
configure_git_identity() {
  local gitconfig="$HOME/.gitconfig"
  local git_name
  local git_email

  info "Checking for local git identity..."
  touch "$gitconfig"
  git_name="$(git config --file "$gitconfig" --get user.name || true)"
  git_email="$(git config --file "$gitconfig" --get user.email || true)"

  if [ -n "$git_name" ] && [ -n "$git_email" ]; then
    success "Git identity already configured ($git_email)"
    return
  fi

  if [ ! -t 0 ]; then
    echo "Not running interactively, skipping git identity setup"
    return
  fi

  while [ -z "$git_name" ]; do
    read -r -p "Enter your git author name: " git_name
  done

  while [ -z "$git_email" ]; do
    read -r -p "Enter your git author email: " git_email
  done

  # git config quotes the values; a heredoc would break on ; # " or \.
  git config --file "$gitconfig" user.name "$git_name"
  git config --file "$gitconfig" user.email "$git_email"

  success "Git identity written to $gitconfig"
}

generate_github_ssh_key() {
  local reply
  local github_email

  info "Checking for existing GitHub SSH key..."
  if [ -f "$HOME/.ssh/github" ]; then
    success "GitHub SSH key already exists"
    return
  fi

  if [ ! -t 0 ]; then
    echo "Not running interactively, skipping GitHub SSH key generation"
    return
  fi

  read -r -p "Generate a GitHub SSH key now? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Skipping GitHub SSH key generation"
    return
  fi

  local default_email
  default_email="$(git config --global --get user.email || true)"

  if [ -n "$default_email" ]; then
    read -r -p "Enter your GitHub email for the SSH key [$default_email]: " github_email
    github_email="${github_email:-$default_email}"
  else
    read -r -p "Enter your GitHub email for the SSH key: " github_email
  fi

  info "Generating GitHub SSH key..."
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "$github_email" -f "$HOME/.ssh/github"

  # Not fatal: the key is still usable, and AddKeysToAgent loads it on first use.
  if ! ssh-add --apple-use-keychain "$HOME/.ssh/github"; then
    error "Could not add the key to the agent; ssh will add it on first use."
  fi

  SSH_KEY_CREATED=true
  success "GitHub SSH key created. Copy the public key below, then add it at https://github.com/settings/ssh/new"
  echo
  cat "$HOME/.ssh/github.pub"
}

# Separate from key generation so a re-run still writes the block if an earlier
# run stopped after creating the key.
configure_github_ssh_host() {
  local ssh_config="$HOME/.ssh/config"

  if [ ! -f "$HOME/.ssh/github" ]; then
    return
  fi

  info "Checking GitHub SSH config..."
  # Ask ssh which keys github.com resolves to, rather than grepping for the
  # key: an IdentityFile under another Host alias doesn't apply to github.com.
  if ssh -G -F "$ssh_config" github.com </dev/null 2>/dev/null |
    grep -Eqx "identityfile (~|$HOME)/\.ssh/github"; then
    success "GitHub SSH config already uses ~/.ssh/github"
    return
  fi

  local host_block
  host_block="$(cat <<'EOF'
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/github
EOF
)"

  # ssh uses the first value it finds, so a block appended after an existing
  # github.com block would be ignored.
  if grep -Eiq '^[[:space:]]*Host[[:space:]]+(.*[[:space:]])?github\.com([[:space:]]|$)' "$ssh_config" 2>/dev/null; then
    error "$ssh_config already has a github.com Host block, so it was left unchanged."
    error "Make sure that block uses the new key, for example:"
    printf '%s\n' "$host_block" >&2
    return
  fi

  printf '\n%s\n' "$host_block" >>"$ssh_config"
  chmod 600 "$ssh_config"
  success "GitHub SSH config written to $ssh_config"
}

# Not fatal: one failed entry (a cask download, a cancelled sudo prompt) fails
# brew bundle, and later steps don't need the rest.
install_homebrew_packages() {
  info "Installing Homebrew packages..."
  # Homebrew won't load formulae from third-party taps until they're trusted.
  # Trusting by name works before the tap is added.
  if ! brew trust --formula anomalyco/tap/opencode-v2; then
    BUNDLE_FAILED=true
    error "Could not trust anomalyco/tap/opencode-v2; brew bundle will fail to install it."
  fi
  # --no-upgrade: a re-run only installs what's missing. Upgrading would quit
  # running apps to replace them; that's for `brew upgrade`.
  if ! brew bundle install --no-upgrade --file="$DOTFILES_DIR/Brewfile"; then
    BUNDLE_FAILED=true
    error "Some Homebrew packages failed to install. Continuing with the remaining steps."
    return
  fi
  success "Homebrew packages installation complete"
}

install_node() {
  info "Checking for Node..."
  eval "$(fnm env --shell bash)"

  if fnm current &>/dev/null && [ "$(fnm current)" != "none" ]; then
    success "Node is already installed ($(fnm current))"
    return
  fi

  info "Installing latest LTS Node with fnm..."
  fnm install --lts
  fnm default lts-latest
  fnm use lts-latest
  success "Node installation complete ($(node --version))"
}

# Homebrew won't install tap formulae with outdated Command Line Tools, and a
# run doesn't update them, so flag it here rather than midway through bundle.
check_command_line_tools() {
  local version
  local latest

  info "Command Line Tools:"
  if ! xcode-select -p &>/dev/null; then
    echo "  not installed; a run would open the installer and stop"
    return
  fi

  # No version when xcode-select points at full Xcode instead.
  if version="$(pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null | awk '/^version:/ { print $2 }')" && [ -n "$version" ]; then
    echo "  installed: $version"
  else
    echo "  installed at $(xcode-select -p)"
  fi

  latest="$(softwareupdate --list 2>&1 | sed -n 's/^\* Label: \(Command Line Tools.*\)$/\1/p' | sort -V | tail -1)"
  if [ -z "$latest" ]; then
    echo "  up to date"
    return
  fi

  echo "  update available: $latest"
  echo "  install with: sudo softwareupdate --install $(printf '%q' "$latest")"
}

check_submodules() {
  local status
  local stale

  info "Submodules:"
  status="$(git -C "$DOTFILES_DIR" submodule status)"

  # '-' means not initialised, '+' means on a different commit than recorded.
  stale="$(printf '%s\n' "$status" | grep -c '^[-+]' || true)"
  if [ "$stale" -eq 0 ]; then
    echo "  all at their recorded commit"
    return
  fi

  printf '%s\n' "$status" | grep '^[-+]' | sed 's/^/  /'
}

check_homebrew_packages() {
  local output
  local missing

  info "Homebrew packages:"
  if [ ! -x /opt/homebrew/bin/brew ]; then
    echo "  Homebrew is not installed; every Brewfile entry would be installed"
    return
  fi

  # Skip auto-update, which can make the check take minutes. --no-upgrade
  # matches a run, which doesn't upgrade outdated entries.
  if output="$(HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --no-upgrade --file="$DOTFILES_DIR/Brewfile" --verbose 2>&1)"; then
    echo "  all installed"
    return
  fi

  missing="$(printf '%s\n' "$output" | grep -c 'needs to be installed' || true)"
  echo "  $missing to install"
  printf '%s\n' "$output" | grep 'needs to be installed' | sed 's/^/  /' || true
}

check_node() {
  local version

  info "Node:"
  if ! command -v fnm &>/dev/null; then
    echo "  fnm is not installed; a run would install it and the latest LTS Node"
    return
  fi

  # fnm current needs fnm env, which writes a multishell dir; fnm default doesn't.
  if version="$(fnm default 2>/dev/null)" && [ -n "$version" ]; then
    echo "  installed: $version"
  else
    echo "  a run would install the latest LTS Node"
  fi
}

# Mirrors ensure_real_dirs, which stops a run when any of these is a symlink.
check_real_dirs() {
  local target="${1:-$HOME}"
  local dir
  local folded=false

  info "Runtime directories:"
  for dir in "${REAL_DIRS[@]}"; do
    if [ -L "$target/$dir" ]; then
      echo "  $target/$dir is a symlink; a run would stop until it is unstowed"
      folded=true
    fi
  done

  if [ "$folded" = false ]; then
    echo "  none folded into the repo"
  fi
}

check_stow_conflicts() {
  local target="${1:-$HOME}"
  local path

  info "Files that would be backed up before symlinking:"
  if ! command -v stow &>/dev/null; then
    echo "  stow is not installed; conflicts are checked once Homebrew installs it"
    return
  fi

  if ! detect_stow_conflicts "$target"; then
    echo "  stow failed for a reason other than a file conflict; a run would stop here:"
    printf '%s\n' "$STOW_ERROR" | sed 's/^/    /'
    return
  fi

  if [ "${#STOW_CONFLICTS[@]}" -eq 0 ]; then
    echo "  none"
    return
  fi

  for path in "${STOW_CONFLICTS[@]}"; do
    echo "  $path"
  done
}

check_prompts() {
  local target="${1:-$HOME}"

  info "Interactive prompts:"
  if git config --file "$target/.gitconfig" --get user.name &>/dev/null &&
    git config --file "$target/.gitconfig" --get user.email &>/dev/null; then
    echo "  git identity: already configured"
  else
    echo "  git identity: would prompt for name and email"
  fi

  if [ -f "$target/.ssh/github" ]; then
    echo "  GitHub SSH key: already exists"
  else
    echo "  GitHub SSH key: would prompt to generate one"
  fi
}

# Every check must be read-only.
run_check() {
  local target="${1:-$HOME}"

  info "Check mode: reporting what a run would change, changing nothing."
  echo

  # Puts brew, stow and fnm on PATH for every check below. Only changes this
  # process's environment.
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  check_command_line_tools
  echo
  check_submodules
  echo
  check_homebrew_packages
  echo
  check_node
  echo
  check_real_dirs "$target"
  echo
  check_stow_conflicts "$target"
  echo
  check_prompts "$target"
}

usage() {
  cat <<EOF
Usage: ${0##*/} [--check]

  --check     Report what a run would change, without changing anything.
  -h, --help  Show this help.
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --check)
        CHECK_MODE=true
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  require_apple_silicon_macos

  if [ "$CHECK_MODE" = true ]; then
    run_check
    exit 0
  fi

  require_command_line_tools
  init_submodules
  install_homebrew
  install_required_packages
  stow_dotfiles
  configure_git_identity
  generate_github_ssh_key
  configure_github_ssh_host
  install_homebrew_packages
  install_node

  # The key was printed before brew bundle, so it has likely scrolled away.
  if [ "$SSH_KEY_CREATED" = true ]; then
    info "Remember to add your SSH key at https://github.com/settings/ssh/new"
    info "Copy it with: pbcopy < ~/.ssh/github.pub"
  fi

  if [ "$BUNDLE_FAILED" = true ]; then
    error "Bootstrap finished, but some Homebrew packages failed to install."
    error "Fix them, then re-run: brew bundle install --no-upgrade --file=\"$DOTFILES_DIR/Brewfile\""
    exit 1
  fi

  success "Bootstrap complete! Please reload your terminal."
}

# Skipped when sourced, so single functions can be tested without a full run.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
