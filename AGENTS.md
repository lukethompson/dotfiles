# dotfiles

Personal dotfiles for Apple Silicon macOS and Debian 13+ (amd64, arm64), deployed as a GNU Stow
symlink farm: zsh configuration, git config, Ghostty config, a Homebrew package manifest, and a
Debian package list plus upstream installers in `bootstrap.sh`.

## Commands

| Command | When |
| --- | --- |
| `./bootstrap.sh` | Full machine setup on either platform. Idempotent — safe to re-run. Installs missing packages but never upgrades them, since an upgrade quits running apps. Ends with a summary; exits 1 if any step failed |
| `stow --dir=. --target="$HOME" --restow .` | After adding, moving, or renaming a stowed file — otherwise new files aren't linked and `$HOME` keeps stale symlinks |
| `brew bundle --file=Brewfile` | Install packages after editing the Brewfile (macOS) |
| `git submodule update --init --recursive` | Fetch the zsh plugins and prompt |

## Verifying changes

There is no build or test suite. Check changes with:

| Command | Checks |
| --- | --- |
| `./bootstrap.sh --check` | Reports what a run would change, changing nothing |
| `bash -n bootstrap.sh` | Script syntax |
| `zsh -n <file>` | Syntax of a changed zsh file |
| `git diff --check` | Whitespace errors |
| `stow --dir=. --target="$HOME" --restow --no .` | Dry run: lists conflicts without linking |
| `ghostty +validate-config` | Ghostty config |

Shell startup, without touching the live config: stow into a scratch home
(`mkdir -p "$tmp/.config/zsh" && stow --dir=. --target="$tmp" .`), then run
`env -i HOME="$tmp" TERM=xterm-256color zsh -lic exit` — once with the normal tools and once with
`PATH=/usr/bin:/bin` — and expect no errors. Debian changes are verified in a throwaway OrbStack
machine (`orb create debian:trixie`, `--arch amd64` for amd64) working on a `git clone` of the
branch, never the Mac's repo through OrbStack's home mount. ShellCheck runs there
(`sudo apt install shellcheck`).

## How deployment works

`stow` symlinks the repo into `$HOME` — `.config/` becomes `~/.config`, `.zshenv` becomes
`~/.zshenv`. Tracked files *are* the live config, with no install step. A running shell doesn't
re-read them. `reload` (`exec zsh`) re-reads `.zshrc` and the aliases only: it starts a
non-login shell that inherits `ZDOTDIR`, so changes to `.zshenv` or `.zprofile` need a new tab
or window. Ghostty reloads its config with ⌘⇧,.

### Which zsh file

- `.zshenv` — environment only: XDG paths, `ZDOTDIR`, `EDITOR`/`VISUAL` (nano), history
  settings, `skip_global_compinit`, `FNM_DIR`, `PNPM_HOME`,
  `CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE`, and the user `PATH`: `~/.local/bin` and fnm's
  default Node first, `$PNPM_HOME/bin` last. `PATH` lives here so commands run over SSH
  (`ssh host cmd`, neither login nor interactive) find Node and pnpm. Zsh reads
  `$ZDOTDIR/.zshenv`, so a nested shell that inherits `ZDOTDIR` skips it and relies on the
  inherited environment.
- `.config/zsh/.zprofile` — login shells. Homebrew, then the same `PATH` entries again:
  on macOS `/etc/zprofile` runs `path_helper` after `.zshenv`, which moves `.zshenv`'s `PATH`
  entries behind the system directories, so any entry that must come first is re-added here.
- `.config/zsh/.zshrc` — interactive shells. Editor (VS Code in VS Code's or code-server's
  terminal, or when `code` is on `PATH`, outside SSH, and on Linux in a graphical session), a
  shared `ssh-agent` on Linux, tools, aliases, completions, plugins. Guard every
  tool with `(( $+commands[tool] ))`: a fresh machine may not have it yet.
- Aliases live in `.config/aliases/base`.

## Conventions

- Machine-specific values belong in untracked machine-local files, never in tracked config:
  `~/.config/aliases/local`, `~/.config/zsh/.zshrc.local`, `~/.gitconfig`
- Shell scripts are bash with `set -euo pipefail`, reporting through the `info`/`success`/`error`
  helpers in `bootstrap.sh`. Every step also calls `record <installed|present|skipped|failed>`
  for the end-of-run summary.
- Platform-specific steps go in `main`'s and `run_check`'s `case "$PLATFORM"`. Tracked shell
  config tells the platforms apart by `$OSTYPE` (`darwin*`), never by whether a command
  exists; command lookups are for tool guards only.
- Every `bootstrap.sh` step that changes the machine needs a matching `check_*` function in
  `run_check`. Check mode must stay read-only.
- Brewfile: taps first, then `brew` and `cask` entries, each sorted by name (ignoring any tap
  prefix) and preceded by a `# description` comment taken from `brew desc`.
- Conventional Commits with a scope: `bootstrap`, `zsh`, `git`, `brewfile`, `stow`, `ghostty`,
  `readme`, `agents` — e.g. `feat(bootstrap):`, `fix(zsh):`, `chore(brewfile):`

## Gotchas

- **Adding a file at the repo root deploys it to `$HOME`.** Add it to `.stow-local-ignore` if it
  should stay in the repo.
- **Stow folds a directory missing from `$HOME` into a single symlink to the repo**, so anything
  an app writes there lands in the repo. Directories written to at runtime (`~/.config`,
  `~/.config/zsh`) must exist as real directories before stowing — list new ones in `REAL_DIRS`
  in `bootstrap.sh`. `~/.config/git` and `~/.config/aliases` are folded on purpose, so
  `aliases/local` lands in the repo, where it is gitignored.
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
  `bootstrap.sh` runs Debian's upstream installers through `run_installer`, which points
  `ZDOTDIR` at a scratch dir, and fails the run if the repo changes anyway.
- **Agent CLIs install differently per platform.** Homebrew on the Mac (Brewfile); official
  installers on Debian, since `npm -g` installs would vanish when fnm switches Node. Never copy
  auth stores (`~/.claude`, `~/.codex`, `~/.config/gh`) between machines.
- **The Debian SSH config must not get `UseKeychain`.** Linux OpenSSH rejects the whole file.
- `.config/zsh/plugins/*` and `.config/zsh/prompt` are git submodules. Do not edit their contents;
  update the submodule instead.
- The git identity lives in the untracked `~/.gitconfig`, written by `bootstrap.sh`. Never
  hardcode an identity in `.config/git/config`. `~/.gitconfig` must exist even when empty:
  without it, `git config --global` writes to the tracked `.config/git/config`.
- `.zshenv` must stay at the repo root. Zsh reads it before `ZDOTDIR` is set, and it is the file
  that points zsh at `~/.config/zsh`.
- Apple Silicon macOS and Debian 13+ on amd64/arm64 only — `detect_platform` exits naming the
  reason otherwise, and refuses root. On the Mac, Homebrew lives at `/opt/homebrew`; scripts test
  for `/opt/homebrew/bin/brew` rather than `command -v brew`, since brew isn't on `PATH` until
  `.zprofile` runs.
