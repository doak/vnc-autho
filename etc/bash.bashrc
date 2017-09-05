if test -z "$SSH_ORIGINAL_COMMAND"; then
    PATH="/bin:$PATH"
    HISTFILE="/etc/.history"
    alias ls="ls --color"

    if test -z "$SSH_AUTH_SOCK"; then
        echo "Start SSH cache agent." >&2
        eval $(ssh-agent) >/dev/null &&
        trap "kill $SSH_AGENT_PID" EXIT &&
        true
    fi

    cd /
fi
