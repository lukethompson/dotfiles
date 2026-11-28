# Share one local agent across shells so AddKeysToAgent never loads keys
# into a forwarded agent.
if (( $+commands[ssh-agent] )); then
  () {
    export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
    # Exit status 2 means no agent answered, even if the socket exists.
    ssh-add -l &>/dev/null
    (( $? != 2 )) && return
    mkdir -p -m 700 ~/.ssh
    # Create the lock file and recheck under the lock to avoid startup races.
    local lock=~/.ssh/agent.lock fd
    : >>$lock
    zmodload -F zsh/system b:zsystem && zsystem flock -t 10 -f fd $lock || return
    ssh-add -l &>/dev/null
    if (( $? == 2 )); then
      rm -f "$SSH_AUTH_SOCK"
      ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null
    fi
    zsystem flock -u $fd
  }
fi

# Docker libraries may need DOCKER_HOST even when the CLI uses a context.
if [[ -S $XDG_RUNTIME_DIR/docker.sock ]]; then
  export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/docker.sock"
fi
