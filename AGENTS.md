# dotfiles

Personal dotfiles deployed with GNU Stow. `bootstrap.sh` supports Apple Silicon macOS and
Debian 13+ (amd64, arm64); run it as your own user, not root. On Debian, a plain run sets up a
base server; `--rootless-docker` and `--dev-tools` add Docker and the dev toolchain (a dev
machine uses both). macOS ignores them.

## Verifying changes

There is no build or test suite. Start with the relevant read-only checks:

| Command | Checks |
| --- | --- |
| `./bootstrap.sh --check` | Reports what a run would change, changing nothing. Takes the Debian options too |
| `/bin/bash -n bootstrap.sh` | Script syntax with the interpreter bootstrap uses |
| `zsh -n <file>` | Syntax of a changed zsh file |
| `git diff --check` | Whitespace errors |
| `stow --dir=. --target="$HOME" --restow --no .` | Dry run: lists conflicts without linking |
| `ghostty +validate-config` | Ghostty config |

To test login-shell startup without deploying to your live home, run from the repo root in a
terminal (or under a pseudo-terminal in automation):

```sh
(
  set -e
  tmp=$(mktemp -d)
  trap 'rm -rf -- "$tmp"' EXIT
  mkdir -p "$tmp/.config/zsh"
  stow --dir=. --target="$tmp" .
  env -i HOME="$tmp" TERM=xterm-256color PATH="$PATH" /bin/zsh -lic ':'
  env -i HOME="$tmp" TERM=xterm-256color PATH=/usr/bin:/bin /bin/zsh -lic ':'
)
```

Both runs should start without errors. The second starts with a minimal `PATH`, but macOS
`.zprofile` can still add Homebrew back.

Test Debian changes in a throwaway OrbStack machine (`orb create debian:trixie`, with
`--arch amd64` for amd64). Clone the branch inside the VM rather than using the Mac's repo
through the home mount. Run ShellCheck there (`sudo apt install shellcheck`). Test a base run,
then `--rootless-docker --dev-tools` on the same machine.

## How deployment works

Once stowed, editing a linked file edits the live config. `reload` (`exec zsh`) starts a
non-login shell that inherits `ZDOTDIR`: it re-reads `.zshrc` and aliases, but `.zshenv` and
`.zprofile` changes need a new terminal tab or window. Ghostty reloads its config with ⌘⇧,.

- **New repo-root files deploy to `$HOME` by default.** Add repo-only files to `.stow-local-ignore`.
- **Stow folds missing directories into symlinks to the repo.** Create `~/.config` and
  `~/.config/zsh` as real directories before stowing so runtime writes don't land in the repo.
  Add new runtime directories to `REAL_DIRS` in `bootstrap.sh`. Git and alias directories are
  folded on purpose; `~/.config/aliases/local` lands in the repo and is gitignored.

These commands change the machine or checkout. Run them for setup or deployment, not verification:

| Command | When |
| --- | --- |
| `./bootstrap.sh` | Full setup. Installs missing packages without upgrading existing ones; backs up conflicting files before stowing |
| `stow --dir=. --target="$HOME" --restow .` | Refresh live links after changing the stowed file layout |
| `brew bundle install --no-upgrade --file=Brewfile` | Install missing Brewfile entries on macOS |
| `git submodule update --init --recursive` | Fetch the zsh plugins and prompt into the checkout |

### Which zsh file

- `.zshenv` — environment only. Keep it at the repo root: zsh reads it before `ZDOTDIR` is set.
  Put user `PATH` entries here so `ssh host cmd` finds Node and pnpm without a login or interactive
  shell. Nested shells inherit `ZDOTDIR` and skip the root `.zshenv`.
- `.config/zsh/.zprofile` — login shells. Restore user `PATH` order after macOS `path_helper`
  and Homebrew setup: `~/.local/bin` and fnm's default Node first, `$PNPM_HOME/bin` last.
- `.config/zsh/.zshrc` — interactive setup. Guard optional tools with
  `(( $+commands[tool] ))` so a fresh machine can start a shell before they're installed. On
  Linux, use the shared local `ssh-agent`, not a forwarded one.
- Aliases live in `.config/aliases/base`.

## Conventions

- Keep machine-specific values in untracked files: `~/.config/aliases/local`,
  `~/.config/zsh/.zshrc.local`, and `~/.gitconfig`. Bootstrap creates `~/.gitconfig` even when
  empty; without it, `git config --global` can write into the tracked `.config/git/config`.
- Shell scripts are bash with `set -euo pipefail`, reporting through the `info`/`success`/`error`
  helpers in `bootstrap.sh`. Every step also calls `record <installed|present|skipped|failed>`
  for the end-of-run summary.
- Platform-specific steps go in `main`'s and `run_check`'s `case "$PLATFORM"`. Tracked shell
  config tells the platforms apart by `$OSTYPE` (`darwin*`), never by whether a command
  exists; command lookups are for tool guards only.
- Debian steps beyond the base machine go behind `--rootless-docker` or `--dev-tools`, in both
  `main` and `run_check`. Retry hints use `$(rerun_command)` so they keep the run's options.
- Reflect new bootstrap machine changes in `--check`. Keep check mode read-only.
- Brewfile: taps first, then `brew` and `cask` entries, each sorted by name (ignoring any tap
  prefix) and preceded by a `# description` comment taken from `brew desc`.
- Conventional Commits with a scope: `bootstrap`, `zsh`, `git`, `brewfile`, `stow`, `ghostty`,
  `readme`, `agents` — e.g. `feat(bootstrap):`, `fix(zsh):`, `chore(brewfile):`

## Gotchas

- **XDG paths are non-standard.** `XDG_DATA_HOME` is `~/.config/local/share` and
  `XDG_CACHE_HOME` is `~/.config/cache`, not under `~/.local`.
- **`bootstrap.sh` runs under macOS's `/bin/bash` 3.2.** No bash 4 features (`mapfile`,
  associative arrays, `${var,,}`). Expanding an empty array errors under `set -u`, so check
  `${#array[@]}` before looping.
- **Third-party tap formulae must be trusted before `brew bundle` loads them.** Adding one to the
  Brewfile means adding a `brew trust` for it in `install_homebrew_packages`.
- **Installers that append to `.zshrc` or `.zprofile` in `$ZDOTDIR` are editing the repo**, since
  both are symlinks into it. Review those changes before committing: guard any `source` of a
  file that only exists on this machine, or move the line into `~/.config/zsh/.zshrc.local`.
  `run_installer` uses a scratch `ZDOTDIR`. Bootstrap checks for repo changes around the
  Brewfile and Debian user-tool steps; it reports edits rather than reverting them.
- **Agent CLIs install differently per platform.** Homebrew on the Mac (Brewfile); official
  installers on Debian, since `npm -g` installs would vanish when fnm switches Node. Never copy
  auth stores (`~/.claude`, `~/.codex`, `~/.config/gh`) between machines.
- **Docker on Debian is rootless**, from Docker's apt repo (the only third-party repo). Never add
  the user to the `docker` group: it is root-equivalent. The root daemon the packages start is
  disabled on purpose.
- **The Debian SSH config must not get `UseKeychain`.** Linux OpenSSH rejects the whole file.
- `.config/zsh/plugins/*` and `.config/zsh/prompt` are git submodules. Do not edit their contents;
  update the submodule instead.
- On macOS, check `/opt/homebrew/bin/brew` directly: it can be installed before `.zprofile`
  puts it on `PATH`.
