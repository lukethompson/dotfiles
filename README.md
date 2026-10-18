# Luke Thompson's dotfiles

My personal dotfiles for macOS and a headless Debian dev machine.

## What's included
- Opinionated zsh configuration with the following plugins:
  - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
  - [zsh-completions](https://github.com/zsh-users/zsh-completions)
  - [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [Pure](https://github.com/sindresorhus/pure/) prompt
- Git configuration, including a global gitignore
- [Ghostty](https://ghostty.org/) configuration
- [Homebrew](https://brew.sh/) package manager for macOS, plus the tools and packages I use — check out
  the [Brewfile](https://github.com/lukethompson/dotfiles/blob/main/Brewfile)

## Supported systems
- Apple Silicon macOS
- Debian 13 or later on amd64 or arm64, used headless over SSH or Mosh. Testing and sid are refused.

## Installation

```bash
# Debian only: a fresh install has no git yet
sudo apt install git
# Clone the repository into your home directory
git clone https://github.com/lukethompson/dotfiles.git
cd dotfiles
# Bootstrap the machine
./bootstrap.sh
# Report what a run would change, changing nothing
./bootstrap.sh --check
```

`bootstrap.sh` is idempotent — it skips anything already installed, so it is safe to
re-run. It doesn't upgrade installed packages. It ends with a summary of every step, and exits
non-zero if any step failed.

Run it as your own user, not root.

### macOS
Installs the Command Line Tools, Homebrew, the Brewfile and Node, links the dotfiles, and
offers to set a git identity and a GitHub SSH key. Upgrade with `brew upgrade`. Claude Code
upgrades its own cask, because `.zshenv` sets `CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE`.

### Debian
Asks for `sudo` only when something system-wide is missing (packages, the terminfo entry), and
installs:

| Tool | From | Update with |
| --- | --- | --- |
| zsh, git, gh, fzf, lazygit, ripgrep, fd, jq, stow, nano, build tools | apt (`APT_PACKAGES` in `bootstrap.sh`) | `sudo apt upgrade` |
| `xterm-ghostty` terminfo | copied from ncurses-term's `ghostty` entry into `/etc/terminfo` | — |
| fnm | official installer → `~/.local/bin` | `curl -fsSL https://fnm.vercel.app/install \| bash -s -- --install-dir ~/.local/bin --skip-shell` |
| Node | latest LTS, through fnm | `fnm install --lts` |
| pnpm | official standalone installer → `$PNPM_HOME/bin` | `pnpm self-update` |
| herdr | official installer → `~/.local/bin` | `herdr update` |
| Claude Code | native installer, latest channel | updates itself |
| Codex | official standalone installer → `~/.local/bin` | re-run the installer |
| OpenCode v2 | official installer → `~/.opencode/bin`, linked into `~/.local/bin` | re-run the installer |

The upstream tools come from their official install scripts at their latest release, unpinned —
the same trust model as the Homebrew installer. Each runs with its shell-config edits redirected to
a scratch directory, since `PATH` is handled by these dotfiles; bootstrap fails if an installer
changes a file in this repo anyway.

`bootstrap.sh` also offers to change your login shell to zsh (`chsh`).

Not handled here, and kept in a separate infrastructure repo: creating the VM, sshd and
mosh-server, Docker, code-server, Caddy, backups, Ansible, WireGuard, locale and timezone, and
Playwright browsers.

## GitHub access

**On the Mac**, `bootstrap.sh` offers to create `~/.ssh/github` and add a `github.com` block to
`~/.ssh/config`, using the macOS keychain.

**On Debian**, use HTTPS through the GitHub CLI instead. Logging in stays a manual step:

```bash
gh auth login --git-protocol https
gh auth setup-git   # writes the credential helper to the untracked ~/.gitconfig
```

On a headless machine with no keyring, gh stores the token unencrypted in
`~/.config/gh/hosts.yml`. Revoke it with `gh auth logout`, or at
<https://github.com/settings/applications>. The SSH key prompt still exists on Debian, defaulting
to no; never copy the Mac's private key there.

On both systems, an existing `github.com` block in `~/.ssh/config` and an existing
`~/.ssh/github.pub` are reported and left alone. Nothing trusts GitHub's host key for you: on
first connection, check it against
[GitHub's published fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints):

```text
SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU (Ed25519)
SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM (ECDSA)
SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s (RSA)
```

Agent CLIs (Claude Code, Codex, OpenCode, gh) are logged in separately on each machine. Never copy
their auth stores between machines.

## Node for scripts and agents
Interactive shells switch Node per directory (`fnm env --use-on-cd`). Every other zsh — `zsh -lc`,
or a command run over SSH like `ssh host 'pnpm install'` — gets fnm's default Node and pnpm
instead. A shell started from an already-running zsh inherits that shell's `PATH`. To
run a command on the version a project's `.node-version` or `.nvmrc` asks for:

```bash
fnm exec -- node -v
```

In a script, `eval "$(fnm env --use-on-cd)"` sets up the same switching as an interactive shell.

## Editor
`git` and other tools that read `$VISUAL`/`$EDITOR` open `code --wait` at the Mac itself, and
`nano` over SSH or on Debian. macOS's `crontab -e` can't run an editor with arguments, so use
`EDITOR=nano crontab -e` there. Override `EDITOR`/`VISUAL` in `~/.config/zsh/.zshrc.local`.

## Local files
You can add untracked local files to provide some machine-specific customizations. Currently the following files are supported:
- `~/.config/aliases/local`
- `~/.config/zsh/.zshrc.local`
- `~/.gitconfig` — your git identity, written by `bootstrap.sh`

## One-time clean-up on an existing Mac
Left over from earlier pnpm setups and not removed by `bootstrap.sh`: the stale
`~/.config/local/share/pnpm/claude` shim and the old `~/Library/pnpm` directory. Check that
nothing still uses them, then delete them by hand. `./bootstrap.sh --check` lists any pnpm global
binary that another command on `PATH` shadows.
