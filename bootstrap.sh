#!/bin/bash

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NOCOLOR='\033[0m'
RED='\033[0;31m'

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Same values .zshenv sets, which isn't linked yet on a fresh machine, so what
# this script installs (brew trust, Node, pnpm) is where later shells look.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$XDG_CONFIG_HOME/local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$XDG_CONFIG_HOME/cache}"
export PNPM_HOME="${PNPM_HOME:-$XDG_DATA_HOME/pnpm}"

# So presence checks find tools already installed there.
export PATH="$HOME/.local/bin:$PATH"

CHECK_MODE=false
PLATFORM=""
STOW_CONFLICTS=()
STOW_ERROR=""

# One "status|name|hint" entry per step, printed at the end. Status is one of
# installed, present, skipped or failed; any failure makes the run exit 1.
SUMMARY=()

# Directories apps write to at runtime (zsh history, compdump), relative to the
# target. They must exist before stowing, or stow replaces each with a single
# symlink and those writes land in the repo.
REAL_DIRS=(.config .config/zsh)

# Debian packages. ncurses-term has Ghostty's terminfo entry.
APT_PACKAGES=(
  build-essential ca-certificates curl fd-find fzf gh git jq lazygit less nano
  ncurses-term openssh-client python3 python3-venv ripgrep stow unzip xz-utils zsh
)

# Docker from Docker's own apt repo, since Debian's docker.io lags upstream
# support. The last three are Debian's, needed to run it rootless.
DOCKER_PACKAGES=(
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  docker-ce-rootless-extras dbus-user-session slirp4netns uidmap
)
# Debian packages Docker's replace. apt-get -y would remove them silently.
DOCKER_CONFLICTS=(docker.io docker-compose docker-doc docker-buildx podman-docker containerd runc)
DOCKER_SOURCES=/etc/apt/sources.list.d/docker.sources
DOCKER_KEY=/etc/apt/keyrings/docker.asc

info() { echo -e "${BLUE}$1${NOCOLOR}"; }
success() { echo -e "${GREEN}$1${NOCOLOR}"; }
error() { echo -e "${RED}$1${NOCOLOR}" >&2; }

# record <installed|present|skipped|failed> <name> [hint]
record() {
  SUMMARY[${#SUMMARY[@]}]="$1|$2|${3:-}"
}

# Prints the summary and returns 1 if any step failed.
print_summary() {
  local entry
  local status
  local name
  local hint
  local failed=0

  echo
  info "Summary:"
  for entry in "${SUMMARY[@]}"; do
    status="${entry%%|*}"
    entry="${entry#*|}"
    name="${entry%%|*}"
    hint="${entry#*|}"
    if [ "$status" = failed ]; then
      failed=1
      echo -e "  ${RED}$(printf '%-9s' "$status")${NOCOLOR} $name"
    else
      printf '  %-9s %s\n' "$status" "$name"
    fi
    if [ -n "$hint" ]; then
      printf '%s\n' "$hint" | sed 's/^/            /'
    fi
  done
  return "$failed"
}

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

unsupported() {
  error "Unsupported system: $1"
  error "These dotfiles support Apple Silicon macOS and Debian 13 or later on amd64 or arm64."
  exit 1
}

# Sets PLATFORM to macos or debian, or exits naming what doesn't match.
detect_platform() {
  local os
  local id=""
  local version_id=""
  local arch

  if [ "$(id -u)" -eq 0 ]; then
    error "Run this as your own user, not root. It asks for sudo when it needs it."
    exit 1
  fi

  os="$(uname -s)"
  case "$os" in
    Darwin)
      arch="$(uname -m)"
      [ "$arch" = arm64 ] || unsupported "macOS on $arch"
      PLATFORM=macos
      ;;
    Linux)
      [ -r /etc/os-release ] || unsupported "Linux without /etc/os-release"
      # A subshell, so os-release's variables don't leak into this script.
      # shellcheck source=/dev/null
      id="$(. /etc/os-release && echo "${ID:-}")"
      # shellcheck source=/dev/null
      version_id="$(. /etc/os-release && echo "${VERSION_ID:-}")"
      [ "$id" = debian ] || unsupported "Linux distribution '${id:-unknown}'"
      # testing and sid have no VERSION_ID.
      case "$version_id" in
        '' | *[!0-9]*) unsupported "Debian without a numeric release (testing or sid?)" ;;
      esac
      [ "$version_id" -ge 13 ] || unsupported "Debian $version_id"
      arch="$(dpkg --print-architecture)"
      case "$arch" in
        amd64 | arm64) ;;
        *) unsupported "Debian on $arch" ;;
      esac
      PLATFORM=debian
      ;;
    *)
      unsupported "$os"
      ;;
  esac

  # Same per-platform value .zshenv sets, so Node installed here is the Node
  # later shells find.
  if [ "$PLATFORM" = macos ]; then
    export FNM_DIR="${FNM_DIR:-$HOME/Library/Application Support/fnm}"
  else
    export FNM_DIR="${FNM_DIR:-$XDG_DATA_HOME/fnm}"
  fi
}

# git ships with the Command Line Tools. xcode-select --install only opens an
# installer window and returns, so stop and ask for a re-run.
require_command_line_tools() {
  info "Checking for Command Line Tools..."
  if xcode-select -p &>/dev/null; then
    success "Command Line Tools are installed"
    record present "Command Line Tools"
    return
  fi

  xcode-select --install
  error "Command Line Tools are not installed. Finish the installer that just opened, then re-run this script."
  exit 1
}

init_submodules() {
  local status="present"

  info "Fetching zsh plugins and prompt..."
  # '-' means not initialised, '+' means on a different commit than recorded.
  if git -C "$DOTFILES_DIR" submodule status | grep -q '^[-+]'; then
    status="installed"
  fi
  git -C "$DOTFILES_DIR" submodule update --init --recursive
  success "Submodules ready"
  record "$status" "zsh plugins and prompt"
}

install_homebrew() {
  info "Checking for Homebrew..."
  # Look for the binary itself. brew isn't on PATH until .zprofile runs, so
  # `command -v brew` would miss an existing install and reinstall it.
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    success "Homebrew is already installed"
    record present Homebrew
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
  record installed Homebrew
}

# stow links the dotfiles and fnm installs Node. Install them on their own so
# a failed Brewfile entry can't leave either one missing.
# Installs only what's missing, since brew install also upgrades.
install_required_packages() {
  local package
  local to_install=()

  info "Checking for stow and fnm..."
  for package in stow fnm; do
    if ! brew list --formula "$package" &>/dev/null; then
      to_install[${#to_install[@]}]="$package"
    fi
  done

  if [ "${#to_install[@]}" -eq 0 ]; then
    success "stow and fnm are installed"
    record present "stow and fnm"
    return
  fi

  info "Installing ${to_install[*]}..."
  brew install "${to_install[@]}"
  success "${to_install[*]} installed"
  record installed "${to_install[*]}"
}

apt_package_installed() {
  [ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" = installed ]
}

# Prints the given packages that aren't installed, space-separated.
missing_apt_packages() {
  local package
  local missing=""

  for package in "$@"; do
    apt_package_installed "$package" || missing="$missing $package"
  done
  echo "${missing# }"
}

# Prints the given packages that are installed, space-separated.
installed_apt_packages() {
  local package
  local installed=""

  for package in "$@"; do
    if apt_package_installed "$package"; then
      installed="$installed $package"
    fi
  done
  echo "${installed# }"
}

# Only touches apt when something is missing, so a re-run needs no password.
install_apt_packages() {
  local missing

  info "Checking Debian packages..."
  missing="$(missing_apt_packages "${APT_PACKAGES[@]}")"
  if [ -z "$missing" ]; then
    success "Debian packages are installed"
    record present "Debian packages"
    return
  fi

  info "Installing Debian packages: $missing"
  # Asks for the password up front and stops if the user can't sudo. Not
  # sudo -v: it asks for a password unless every sudoers entry is NOPASSWD.
  if ! sudo true; then
    error "Installing packages needs sudo. Get sudo access, then re-run this script."
    exit 1
  fi
  sudo apt-get update
  # Unquoted on purpose: one argument per package.
  # shellcheck disable=SC2086
  sudo apt-get install -y $missing
  success "Debian packages installed"
  record installed "Debian packages" "$missing"
}

# Debian ships fd as fdfind. A symlink, unlike an alias, also works for
# scripts and agents.
link_fd() {
  local link="$HOME/.local/bin/fd"

  info "Checking for fd..."
  if command -v fd &>/dev/null; then
    success "fd is on PATH"
    record present fd
    return
  fi

  if [ -e "$link" ] || [ -L "$link" ]; then
    error "$link exists but isn't a working fd, so it was left unchanged."
    record skipped fd "$link exists but doesn't run; replace it with: ln -sf /usr/bin/fdfind $link"
    return
  fi

  ln -s /usr/bin/fdfind "$link"
  success "Linked $link to fdfind"
  record installed "fd (links to fdfind)"
}

# Whether the entry is in a system directory. A copy in ~/.terminfo doesn't
# count, since root can't see it under sudo.
ghostty_terminfo_installed() {
  env -u TERMINFO -u TERMINFO_DIRS HOME=/nonexistent infocmp xterm-ghostty &>/dev/null
}

# Ghostty sends TERM=xterm-ghostty over SSH, but ncurses-term calls the entry
# ghostty. Copy it under Ghostty's name into /etc/terminfo, Debian's directory
# for local entries, so it works under sudo too.
install_ghostty_terminfo() {
  info "Checking for the xterm-ghostty terminfo entry..."
  if ghostty_terminfo_installed; then
    success "xterm-ghostty terminfo entry found"
    record present "xterm-ghostty terminfo"
    return
  fi

  if ! infocmp -x ghostty 2>/dev/null |
    sed 's/^ghostty|/xterm-ghostty|/' |
    sudo tic -x -o /etc/terminfo - ||
    ! ghostty_terminfo_installed; then
    error "Could not create the xterm-ghostty terminfo entry."
    record failed "xterm-ghostty terminfo" "Over SSH from Ghostty, set TERM=xterm-256color instead"
    return
  fi
  success "xterm-ghostty terminfo entry written to /etc/terminfo"
  record installed "xterm-ghostty terminfo"
}

# The signing key and a deb822 sources file, as in Docker's install guide.
add_docker_repo() {
  local key
  local codename
  local arch
  local status=0

  key="$(mktemp)"
  # A subshell, so os-release's variables don't leak into this script.
  # shellcheck source=/dev/null
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
  arch="$(dpkg --print-architecture)"

  if curl -fsSL https://download.docker.com/linux/debian/gpg -o "$key" &&
    sudo install -m 0755 -d /etc/apt/keyrings &&
    sudo install -m 0644 "$key" "$DOCKER_KEY"; then
    printf '%s\n' \
      "Types: deb" \
      "URIs: https://download.docker.com/linux/debian" \
      "Suites: $codename" \
      "Components: stable" \
      "Architectures: $arch" \
      "Signed-By: $DOCKER_KEY" |
      sudo tee "$DOCKER_SOURCES" >/dev/null || status=$?
  else
    status=1
  fi
  rm -f "$key"
  return "$status"
}

# Not fatal: nothing later needs Docker, so a failure is recorded and the run
# carries on.
install_docker() {
  local conflicts
  local missing

  info "Checking Docker..."
  conflicts="$(installed_apt_packages "${DOCKER_CONFLICTS[@]}")"
  if [ -n "$conflicts" ]; then
    error "Debian's Docker packages are installed ($conflicts), which Docker's own packages replace."
    record failed Docker "Remove them with: sudo apt remove $conflicts, then re-run ./bootstrap.sh"
    return
  fi

  missing="$(missing_apt_packages "${DOCKER_PACKAGES[@]}")"
  if [ -z "$missing" ]; then
    success "Docker packages are installed"
    record present "Docker packages"
  else
    info "Installing Docker packages: $missing"
    if [ ! -f "$DOCKER_SOURCES" ] && ! add_docker_repo; then
      error "Could not add Docker's apt repo."
      record failed "Docker packages" "Re-run ./bootstrap.sh to retry"
      return
    fi
    # Unquoted on purpose: one argument per package.
    # shellcheck disable=SC2086
    if ! sudo apt-get update || ! sudo apt-get install -y $missing; then
      error "Docker packages failed to install. Continuing with the remaining steps."
      record failed "Docker packages" "Re-run ./bootstrap.sh to retry"
      return
    fi
    success "Docker packages installed"
    record installed "Docker packages" "$missing"
  fi

  setup_rootless_docker
}

# Whether the root daemon the packages start is enabled or running.
rootful_docker_enabled() {
  systemctl is-enabled --quiet docker.service docker.socket 2>/dev/null ||
    systemctl is-active --quiet docker.service docker.socket 2>/dev/null
}

rootless_docker_enabled() {
  systemctl --user is-enabled --quiet docker.service 2>/dev/null
}

linger_enabled() {
  [ "$(loginctl show-user "$(id -un)" --property=Linger --value 2>/dev/null)" = yes ]
}

# Rootless: the daemon runs as this user under systemd --user, so docker needs
# neither sudo nor the docker group, which is root-equivalent. The setup tool
# creates and switches to a "rootless" CLI context. Linger keeps the daemon
# running after logout.
setup_rootless_docker() {
  local user
  local status=present

  info "Checking rootless Docker..."
  user="$(id -un)"

  if rootful_docker_enabled; then
    info "Stopping the root Docker daemon..."
    if ! sudo systemctl disable --now docker.service docker.socket ||
      ! sudo rm -f /var/run/docker.sock; then
      error "Could not stop the root Docker daemon."
      record failed "rootless Docker" "Stop it with: sudo systemctl disable --now docker.service docker.socket"
      return
    fi
    status=installed
  fi

  if ! rootless_docker_enabled; then
    # The setup tool needs subordinate IDs, which adduser normally assigns.
    if ! grep -q "^$user:" /etc/subuid 2>/dev/null || ! grep -q "^$user:" /etc/subgid 2>/dev/null; then
      error "$user has no subordinate IDs in /etc/subuid and /etc/subgid."
      record failed "rootless Docker" "Add them with: sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $user"
      return
    fi
    if ! dockerd-rootless-setuptool.sh install; then
      error "Rootless Docker setup failed."
      record failed "rootless Docker" "Re-run ./bootstrap.sh to retry"
      return
    fi
    status=installed
  fi

  if ! linger_enabled; then
    if ! sudo loginctl enable-linger "$user"; then
      error "Could not enable linger, so Docker stops when you log out."
      record failed "rootless Docker" "Enable it with: sudo loginctl enable-linger $user"
      return
    fi
    status=installed
  fi

  success "Rootless Docker is set up"
  record "$status" "rootless Docker"
}

# Downloads an installer to a file before running it, so a dropped connection
# can't run half a script. Installers add their directory to a shell rc file;
# ZDOTDIR points them at a scratch dir, since the real .zshrc is a symlink into
# this repo. Their edits are reported and discarded: PATH already covers where
# each tool installs.
# run_installer <url> <interpreter> [installer args...]
run_installer() {
  local url="$1"
  local interpreter="$2"
  shift 2
  local script
  local scratch
  local status=0
  local file

  script="$(mktemp)"
  scratch="$(mktemp -d)"

  if curl -fsSL "$url" -o "$script"; then
    SHELL="$(command -v zsh)" ZDOTDIR="$scratch" "$interpreter" "$script" "$@" || status=$?
  else
    error "Could not download $url"
    status=1
  fi

  for file in "$scratch"/.[!.]* "$scratch"/*; do
    [ -e "$file" ] || continue
    info "Discarded the installer's edit to ${file##*/}; PATH is handled by the dotfiles."
  done

  rm -rf "$script" "$scratch"
  return "$status"
}

# fnm is needed for Node, so a failure stops the run.
install_fnm() {
  info "Checking for fnm..."
  if command -v fnm &>/dev/null; then
    success "fnm is already installed"
    record present fnm
    return
  fi

  info "Installing fnm..."
  if ! run_installer https://fnm.vercel.app/install bash --install-dir "$HOME/.local/bin" --skip-shell; then
    error "fnm installation failed"
    exit 1
  fi
  success "fnm installed"
  record installed fnm
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

# Whether a restow would change anything. On an up-to-date target the dry run
# unlinks every link and relinks it, marking each relink "(reverts previous
# action)"; any other action, or a failed dry run (a conflict), is a change.
stow_would_change() {
  local target="$1"
  local output
  local unlinks
  local relinks

  if ! output="$(stow --dir="$DOTFILES_DIR" --target="$target" --restow --no -v . 2>&1)"; then
    return 0
  fi
  if printf '%s\n' "$output" | grep -E '^[A-Z]+: ' | grep -Ev '^(UNLINK|WARNING): |^LINK: .*\(reverts previous action\)$' | grep -q .; then
    return 0
  fi
  unlinks="$(printf '%s\n' "$output" | grep -c '^UNLINK: ' || true)"
  relinks="$(printf '%s\n' "$output" | grep -c '^LINK: .*(reverts previous action)$' || true)"
  [ "$unlinks" -ne "$relinks" ]
}

stow_dotfiles() {
  local target="${1:-$HOME}"
  local status=present

  ensure_real_dirs "$target"
  if stow_would_change "$target"; then
    status=installed
  fi
  resolve_stow_conflicts "$target"

  info "Symlinking dotfiles into $target..."
  stow --dir="$DOTFILES_DIR" --target="$target" --restow .
  success "Dotfiles symlinked"
  record "$status" "dotfiles symlinks"
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
    record present "git identity"
    return
  fi

  if [ ! -t 0 ]; then
    echo "Not running interactively, skipping git identity setup"
    record skipped "git identity" "Re-run ./bootstrap.sh in a terminal to set it"
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
  record installed "git identity"
}

# Debian only. Through sudo, which is usually still unlocked from the apt step
# and works for an account without a password, unlike plain chsh.
configure_login_shell() {
  local user
  local current
  local zsh_path
  local hint

  info "Checking login shell..."
  user="$(id -un)"
  zsh_path="$(command -v zsh)"
  current="$(getent passwd "$user" | cut -d: -f7)"
  hint="Change it with: sudo chsh -s $zsh_path $user"

  if [ "${current##*/}" = zsh ]; then
    success "Login shell is already zsh"
    record present "zsh login shell"
    return
  fi

  # Without a terminal, only if sudo needs no password.
  if [ ! -t 0 ] && ! sudo -n true 2>/dev/null; then
    echo "Not running interactively, leaving the login shell as $current"
    record skipped "zsh login shell" "$hint"
    return
  fi

  info "Changing the login shell from $current to $zsh_path..."
  if ! sudo chsh -s "$zsh_path" "$user"; then
    error "Could not change the login shell."
    record failed "zsh login shell" "$hint"
    return
  fi
  success "Login shell changed to $zsh_path; it applies from the next login"
  record installed "zsh login shell"
}

generate_github_ssh_key() {
  local reply
  local github_email

  info "Checking for existing GitHub SSH key..."
  if [ -f "$HOME/.ssh/github" ]; then
    success "GitHub SSH key already exists"
    record present "GitHub SSH key"
    return
  fi

  # ssh-keygen would overwrite it, and it may be registered somewhere.
  if [ -e "$HOME/.ssh/github.pub" ]; then
    error "$HOME/.ssh/github.pub exists without its private key, so no key was generated."
    record skipped "GitHub SSH key" "Move ~/.ssh/github.pub aside, then re-run ./bootstrap.sh"
    return
  fi

  if [ ! -t 0 ]; then
    echo "Not running interactively, skipping GitHub SSH key generation"
    record skipped "GitHub SSH key"
    return
  fi

  read -r -p "Generate a GitHub SSH key now? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Skipping GitHub SSH key generation"
    record skipped "GitHub SSH key"
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
  add_key_to_agent "$HOME/.ssh/github"

  success "GitHub SSH key created. Copy the public key below, then add it at https://github.com/settings/ssh/new"
  echo
  cat "$HOME/.ssh/github.pub"

  local copy_hint="cat ~/.ssh/github.pub"
  if [ "$PLATFORM" = macos ]; then
    copy_hint="pbcopy < ~/.ssh/github.pub"
  fi
  record installed "GitHub SSH key" "Add it at https://github.com/settings/ssh/new
Copy it with: $copy_hint"
}

add_key_to_agent() {
  local key="$1"
  local status=0

  if [ "$PLATFORM" = macos ]; then
    if ! ssh-add --apple-use-keychain "$key"; then
      error "Could not add the key to the agent; ssh will add it on first use."
    fi
    return
  fi

  # Exit 2 means no agent is reachable. .zshrc starts one in each new zsh session,
  # and AddKeysToAgent loads the key into it on first use.
  ssh-add -l &>/dev/null || status=$?
  if [ "$status" -eq 2 ]; then
    echo "No ssh-agent is running yet; the key is added on first use in a new zsh session."
    return
  fi
  if ! ssh-add "$key"; then
    error "Could not add the key to the agent; ssh will add it on first use."
  fi
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
    record present "GitHub SSH config"
    return
  fi

  # UseKeychain is macOS-only; OpenSSH elsewhere rejects the whole file.
  local host_block
  if [ "$PLATFORM" = macos ]; then
    host_block="$(cat <<'EOF'
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/github
EOF
)"
  else
    host_block="$(cat <<'EOF'
Host github.com
  AddKeysToAgent yes
  IdentityFile ~/.ssh/github
EOF
)"
  fi

  # ssh uses the first value it finds, so a block appended after an existing
  # github.com block would be ignored.
  if grep -Eiq '^[[:space:]]*Host[[:space:]]+(.*[[:space:]])?github\.com([[:space:]]|$)' "$ssh_config" 2>/dev/null; then
    error "$ssh_config already has a github.com Host block, so it was left unchanged."
    error "Make sure that block uses the new key, for example:"
    printf '%s\n' "$host_block" >&2
    record skipped "GitHub SSH config" "$ssh_config already has a github.com block; point it at ~/.ssh/github"
    return
  fi

  printf '\n%s\n' "$host_block" >>"$ssh_config"
  chmod 600 "$ssh_config"
  success "GitHub SSH config written to $ssh_config"
  record installed "GitHub SSH config"
}

# Not fatal: one failed entry (a cask download, a cancelled sudo prompt) fails
# brew bundle, and later steps don't need the rest.
install_homebrew_packages() {
  info "Installing Homebrew packages..."
  # Homebrew won't load formulae from third-party taps until they're trusted.
  # Trusting by name works before the tap is added.
  if ! brew trust --formula anomalyco/tap/opencode-v2; then
    error "Could not trust anomalyco/tap/opencode-v2; brew bundle will fail to install it."
    record failed "brew trust anomalyco/tap/opencode-v2"
  fi
  # --no-upgrade: a re-run only installs what's missing. Upgrading would quit
  # running apps to replace them; that's for `brew upgrade`.
  if ! brew bundle install --no-upgrade --file="$DOTFILES_DIR/Brewfile"; then
    error "Some Homebrew packages failed to install. Continuing with the remaining steps."
    record failed "Homebrew packages" "Fix them, then re-run: brew bundle install --no-upgrade --file=\"$DOTFILES_DIR/Brewfile\""
    return
  fi
  success "Homebrew packages installation complete"
  record installed "Homebrew packages"
}

pnpm_installed() { [ -x "$PNPM_HOME/bin/pnpm" ]; }

# The standalone pnpm bundles its own Node, so it keeps working when fnm
# switches version. It installs to $PNPM_HOME/bin, which is on PATH.
install_pnpm() {
  run_installer https://get.pnpm.io/install.sh bash
}

install_herdr() {
  HERDR_INSTALL_DIR="$HOME/.local/bin" run_installer https://herdr.dev/install.sh sh
}

# The native install updates itself. latest matches the Mac's claude-code@latest.
install_claude() {
  run_installer https://claude.ai/install.sh bash latest
}

install_codex() {
  CODEX_NON_INTERACTIVE=1 run_installer https://chatgpt.com/codex/install.sh sh
}

# OpenCode installs to ~/.opencode/bin; link it into ~/.local/bin. This only
# runs when opencode isn't on PATH, so any existing link is broken.
install_opencode() {
  local link="$HOME/.local/bin/opencode"

  run_installer https://raw.githubusercontent.com/anomalyco/opencode/v2/install bash --no-modify-path || return
  if [ -L "$link" ]; then
    rm "$link"
  fi
  ln -s "$HOME/.opencode/bin/opencode" "$link"
}

# Not fatal: nothing later depends on these, so a failure is recorded and the
# run carries on. Installs only what's missing, like brew bundle --no-upgrade.
# install_user_tool <name> <command that succeeds when installed> <install command>
install_user_tool() {
  local name="$1"
  local installed="$2"
  local install="$3"

  info "Checking for $name..."
  if "$installed"; then
    success "$name is already installed"
    record present "$name"
    return
  fi

  info "Installing $name..."
  if "$install" && "$installed"; then
    success "$name installed"
    record installed "$name"
  else
    error "$name installation failed. Continuing with the remaining steps."
    record failed "$name" "Re-run ./bootstrap.sh to retry"
  fi
}

has_command() { command -v "$1" &>/dev/null; }
herdr_installed() { has_command herdr; }
claude_installed() { has_command claude; }
codex_installed() { has_command codex; }
opencode_installed() { has_command opencode; }

install_user_tools() {
  install_user_tool pnpm pnpm_installed install_pnpm
  install_user_tool herdr herdr_installed install_herdr
  install_user_tool "Claude Code" claude_installed install_claude
  install_user_tool Codex codex_installed install_codex
  install_user_tool OpenCode opencode_installed install_opencode
}

# Fingerprint of the repo's working tree, to catch an installer that edits a
# tracked file through a symlink.
repo_state() {
  { git -C "$DOTFILES_DIR" status --porcelain; git -C "$DOTFILES_DIR" diff; } | cksum
}

# Never restores anything: the change may be wanted, so it's left for review.
check_repo_unchanged() {
  local before="$1"

  if [ "$(repo_state)" = "$before" ]; then
    return
  fi

  error "An installer changed files in $DOTFILES_DIR:"
  git -C "$DOTFILES_DIR" status --short >&2
  record failed "dotfiles repo left unchanged by installers" "Review with: git -C \"$DOTFILES_DIR\" diff"
}

install_node() {
  info "Checking for Node..."
  eval "$(fnm env --shell bash)"

  if fnm current &>/dev/null && [ "$(fnm current)" != "none" ]; then
    success "Node is already installed ($(fnm current))"
    record present "Node $(fnm current)"
    return
  fi

  info "Installing latest LTS Node with fnm..."
  fnm install --lts
  fnm default lts-latest
  fnm use lts-latest
  success "Node installation complete ($(node --version))"
  record installed "Node $(node --version)"
}

# Interactive: gh logs in through the browser or a device code, and asks
# before uploading an SSH key. Runs after the packages, which install gh on the
# Mac.
login_github_cli() {
  local login="gh auth login --hostname github.com --git-protocol ssh"
  local reply

  info "Checking GitHub CLI login..."
  if ! command -v gh &>/dev/null; then
    error "gh is not installed, so the GitHub CLI login was skipped."
    record skipped "GitHub CLI login" "Install gh, then run: $login"
    return
  fi

  if gh auth status --hostname github.com &>/dev/null; then
    success "GitHub CLI is logged in"
    record present "GitHub CLI login"
    return
  fi

  if [ ! -t 0 ]; then
    echo "Not running interactively, skipping GitHub CLI login"
    record skipped "GitHub CLI login" "Log in with: $login"
    return
  fi

  read -r -p "Log in to the GitHub CLI now? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Skipping GitHub CLI login"
    record skipped "GitHub CLI login" "Log in with: $login"
    return
  fi

  if ! gh auth login --hostname github.com --git-protocol ssh; then
    error "GitHub CLI login failed."
    record failed "GitHub CLI login" "Log in with: $login"
    return
  fi
  success "GitHub CLI logged in"
  record installed "GitHub CLI login"
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
  if ! command -v git &>/dev/null; then
    echo "  git is not installed; a run installs it, then fetches them"
    return
  fi
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

check_apt_packages() {
  local missing

  info "Debian packages:"
  missing="$(missing_apt_packages "${APT_PACKAGES[@]}")"
  if [ -z "$missing" ]; then
    echo "  all installed"
    return
  fi
  echo "  $(echo "$missing" | wc -w | tr -d ' ') to install: $missing"
}

check_docker() {
  local conflicts
  local missing

  info "Docker:"
  conflicts="$(installed_apt_packages "${DOCKER_CONFLICTS[@]}")"
  if [ -n "$conflicts" ]; then
    echo "  Debian's Docker packages are installed ($conflicts); a run would skip Docker until they're removed"
    return
  fi

  missing="$(missing_apt_packages "${DOCKER_PACKAGES[@]}")"
  if [ -n "$missing" ]; then
    if [ ! -f "$DOCKER_SOURCES" ]; then
      echo "  a run would add Docker's apt repo"
    fi
    echo "  $(echo "$missing" | wc -w | tr -d ' ') to install: $missing"
  else
    echo "  packages installed"
  fi

  if rootful_docker_enabled; then
    echo "  a run would stop and disable the root daemon"
  fi
  if rootless_docker_enabled; then
    echo "  rootless daemon enabled"
  else
    echo "  a run would set up rootless Docker"
  fi
  if ! linger_enabled; then
    echo "  a run would enable linger"
  fi
}

check_user_tools() {
  info "User tools:"
  check_user_tool fd "has_command fd" "link ~/.local/bin/fd to fdfind"
  check_user_tool "xterm-ghostty terminfo" ghostty_terminfo_installed "copy it from the ghostty entry into /etc/terminfo"
  check_user_tool fnm "has_command fnm" "install it"
  check_user_tool pnpm pnpm_installed "install it"
  check_user_tool herdr herdr_installed "install it"
  check_user_tool "Claude Code" claude_installed "install it"
  check_user_tool Codex codex_installed "install it"
  check_user_tool OpenCode opencode_installed "install it"
}

# check_user_tool <name> <check command> <what a run would do>
check_user_tool() {
  # Unquoted so "has_command fd" splits into a command and its argument.
  # shellcheck disable=SC2086
  if $2 &>/dev/null; then
    echo "  $1: installed"
  else
    echo "  $1: a run would $3"
  fi
}

check_login_shell() {
  local current

  info "Login shell:"
  current="$(getent passwd "$(id -un)" | cut -d: -f7)"
  if [ "${current##*/}" = zsh ]; then
    echo "  zsh"
  else
    echo "  $current; a run would change it to zsh"
  fi
}

# $PNPM_HOME/bin is last on PATH, so a global binary there never runs if
# another command has the same name. List those.
check_pnpm_shadowing() {
  local file
  local name
  local found
  local shadowed=false

  info "pnpm global binaries:"
  for file in "$PNPM_HOME"/bin/*; do
    [ -e "$file" ] || continue
    name="${file##*/}"
    found="$(command -v "$name" 2>/dev/null || true)"
    if [ -n "$found" ] && [ "$found" != "$file" ]; then
      echo "  $name: shadowed by $found"
      shadowed=true
    fi
  done

  if [ "$shadowed" = false ]; then
    echo "  none shadowed"
  fi
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
    echo "  stow is not installed; conflicts are checked once a run installs it"
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
  elif [ -e "$target/.ssh/github.pub" ]; then
    echo "  GitHub SSH key: ~/.ssh/github.pub exists without its private key; a run would skip it"
  else
    echo "  GitHub SSH key: would prompt to generate one"
  fi

  if ! command -v gh &>/dev/null; then
    echo "  GitHub CLI login: gh is not installed yet; a run would offer to log in once it is"
  elif gh auth status --hostname github.com &>/dev/null; then
    echo "  GitHub CLI login: already logged in"
  else
    echo "  GitHub CLI login: would prompt to log in"
  fi
}

# Every check must be read-only.
run_check() {
  local target="${1:-$HOME}"

  info "Check mode: reporting what a run would change, changing nothing."
  echo

  case "$PLATFORM" in
    macos)
      # Put brew, stow and fnm on PATH for the checks below (this process only).
      if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi

      check_command_line_tools
      echo
      check_submodules
      echo
      check_homebrew_packages
      ;;
    debian)
      check_apt_packages
      echo
      check_submodules
      echo
      check_user_tools
      echo
      check_docker
      echo
      check_login_shell
      ;;
  esac
  echo
  check_node
  echo
  check_pnpm_shadowing
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
  local repo_before

  parse_args "$@"
  detect_platform

  if [ "$CHECK_MODE" = true ]; then
    run_check
    exit 0
  fi

  # Installers write here; it must be a real directory, never a stow link.
  mkdir -p "$HOME/.local/bin"

  case "$PLATFORM" in
    macos)
      require_command_line_tools
      init_submodules
      install_homebrew
      install_required_packages
      ;;
    debian)
      install_apt_packages
      init_submodules
      link_fd
      install_ghostty_terminfo
      install_docker
      install_fnm
      ;;
  esac

  stow_dotfiles
  configure_git_identity
  if [ "$PLATFORM" = debian ]; then
    configure_login_shell
  fi
  generate_github_ssh_key
  configure_github_ssh_host

  repo_before="$(repo_state)"
  case "$PLATFORM" in
    macos) install_homebrew_packages ;;
    debian) install_user_tools ;;
  esac
  check_repo_unchanged "$repo_before"

  install_node
  login_github_cli

  # Last, since the SSH key and any errors have likely scrolled away.
  if ! print_summary; then
    echo
    error "Bootstrap finished, but some steps failed. See the summary above."
    exit 1
  fi

  echo
  success "Bootstrap complete! Please reload your terminal."
}

# Skipped when sourced, so single functions can be tested without a full run.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
