SSH_CTL_SOCKET="./tmp/ssh_ctl-socket.$$"
SSH_PID_FILE="./tmp/sshd-pid.$$"
SSH_HOST_KEY="./etc/ssh_host_ecdsa_key"
SSH_AUTHORIZED="./etc/ssh_authorized_keys"
SSH_CONF="./etc/ssh_config"
SSH_KEY="./etc/ssh_key"
SSH_BANNER="./etc/ssh_banner"

# Fix permission issue if extracted on Windows.
ssh_fix_permission() {
    local key="$1"
    chmod 600 "$key"
}

# Start ssh-agent if not already running.
ssh_cache() {
    ssh_fix_permission "$SSH_KEY" &&
    if test -z "$SSH_AUTH_SOCK"; then
        info "Start SSH cache agent."
        eval $(ssh-agent) >/dev/null
        push_cleanup kill "$SSH_AGENT_PID"
        push_cleanup unset SSH_AGENT_PID
        push_cleanup unset SSH_AUTH_SOCK
    fi
}

sshd_listen() {
    local port="$1"
    shift
    local pid

    local sshd="`PATH+=":/usr/sbin:/sbin:" which sshd`"
    test -n "$sshd" ||
    fail "No sshd available."

    verb "Starting sshd on port $port ..."
    mkfifo "$CMD_PIPE" &&
    push_cleanup rm "$CMD_PIPE" &&
    # Paths starting with '//' are interpreted by Cygwin as a samba share. '$PWD' is '/' in Cygwin, therefore this has to be avoided.
    #FIXME Does not fail if host key is not available.
    #FIXME Denies connection off SSH clients if AuthorizedKeysFile is below '/tmp'.
    "$sshd" -f etc/sshd_config -o Port="$port" -o PidFile="/./$PWD/$SSH_PID_FILE" -o Banner="/.$PWD/$SSH_BANNER" -o HostKey="/./$PWD/$SSH_HOST_KEY" -o AuthorizedKeysFile="/./$PWD/$SSH_AUTHORIZED" -o ForceCommand="cat >/./$PWD/$CMD_PIPE" "$@"
    #FIXME workaround to get file be created.
    sleep 0.2
    if test -e "$SSH_PID_FILE"; then
        pid="`cat "$SSH_PID_FILE"`"
        push_cleanup killtree "$pid"
    else
        fail "Failed to start sshd."
    fi
}

# Handle specual because SSH connection sometimes breaks completely, but sometimes the base connection is still there and it does not need to be re-established. Every socket has to be removed only once, use an hash table to get a "set".
declare -A SSH_CTL_SOCKETS
cleanup_ssh() {
    for socket in "${SSH_CTL_SOCKETS[@]}"; do
        ssh -S "$socket" -O exit dummy
    done
    unset SSH_CTL_SOCKETS
}
push_cleanup cleanup_ssh

ssh_tunnel() {
    local host="$1"
    local vnc_conf="$2"
    shift 2
    local conf_args

    if "$vnc_conf"; then
        conf_args=(-F "$SSH_CONF")
    fi &&
    if ! test -e "$SSH_CTL_SOCKET.$host"; then
        $D ssh "${conf_args[@]}" -fN -MS "$SSH_CTL_SOCKET.$host" "$@" "$host" &&
        SSH_CTL_SOCKETS["$host"]="$SSH_CTL_SOCKET.$host"
    fi &&
    true
}

ssh_connect() {
    $D ssh -F "$SSH_CONF" "$@"
}
