#!/bin/bash

COPYRIGHT="Copyright © 2017 Korbinian Demmel"
LICENSE="This program is distributed under the terms of the GNU General Public License version 3 (GPLv3)."

BASEDIR="`dirname "$0"`/.."
RESTART_DELAY="1"
CMD_PIPE="tmp/ssh_cmd_pipe"

vncserver_variants=(
    "winvnc4"
    "x11vnc"
)

vncviewer_variants=(
    "vncviewer.exe"
    "xtightvncviewer"
    "xtigervncviewer"
    "vncviewer"
)

source "$BASEDIR/bin/tools.bash" &&
source "$BASEDIR/bin/ssh-tunnel.bash" &&
source "$BASEDIR/etc/host.conf" &&
true ||
fail "Failed to source files."

print_version() {
    local VERSION
    local DATE

    (
        extract_version 2>/dev/null

        echo "vnc-autho: $CONFIG${CONFIG:+-}$VERSION ($DATE)"
        echo "$COPYRIGHT"
        echo "$LICENSE"
        if $do_patch; then
            echo "**** PATCH START ****"
            cat "$PATCH_FILE"
            echo "**** PATCH  END  ****"
        fi
        test -f "$VERSION_FILE" ||
        rm -f "$PATCH_FILE"
    )
}

syntax() {
    cat << EOF
SYNTAX: $0 [<help>] <command> [<hostspec>] [--listen] [--ssh-gw <hostspec>] [--vnc|--ssh <args> --]...
        <help>          = [--help|--version] [--patch] [--create-version-file]
        <command>       = server|viewer|ANY
                          Command 'ANY' implies '--listen'.
        <hostspec>      = [<user>@]<host>[:<port>][::<tunnelspec>]
        <tunnelspec>    = <tunnel-port-a>[::[<tunnel-port-b>]]
        <args>          = Extra arguments passed through to tool.
        --listen        = Listen for incoming SSH connections.
        --ssh-gw        = Gateway final SSH connection through (third-party) SSH server.
                          Needed if the viewer AND server are both not accessible from each other.

EOF
print_current_variables
}

print_current_variables() {
    cat << EOF
        Options:
            --listen:   $do_listen
            --ssh-gw:   '$arg_ssh_gw'
        Additional arguments for VNC server/viewer: `print_values_quoted "${arg_vnc[@]}"`
        Additional arguments for SSH server/client: `print_values_quoted "${arg_ssh[@]}"`
EOF
}

do_help=false
do_only_version=false
do_patch=false
do_create_version_file=false
do_listen=false
while test -n "$1"; do
    case "$1" in
        "-h"|"--help")
            do_help=true
            shift
            ;;
        "-v"|"--version")
            do_only_version=true
            shift
            ;;
        "--create-version-file")
            set_flag "$1"
            do_patch=true
            extract_version ||
            fail "Failed to ceate version file '$VERSION_FILE'."
            exit $?
            ;;
        "--listen"|"--no-listen"|\
        "--patch"|"--no-patch")
            set_flag "$1"
            shift
            ;;
        "--ssh-gw")
            get_arg '^--' "$1" "$2" &&
            shift $__ ||
            fail "Incomplete option."
            ;;
        "--no-ssh-gw")
            unset arg_ssh_gw
            shift
            ;;
        "--vnc"|\
        "--ssh")
            get_args '$+$' '^--' "$@" &&
            shift $__
            ;;
        "--")
            shift
            break
            ;;
        "-"*)
            fail "Unknown option: '$1'"
            ;;

        *)
            if test -z "$arg_command"; then
                get_arg '$A$' '^--' "<command>" "$1" &&
                shift 1
                test "$arg_command" = "ANY" &&
                do_listen=true
            elif test -z "$arg_hostspec"; then
                get_arg '$A$' '^--' "<hostspec>" "$1" &&
                shift 1
            else
                fail "Duplicate <hostspec>: '$1'"
            fi
            ;;
    esac
done

if $do_help; then
    syntax
    echo
    print_version
    exit 0
fi
print_version
$do_only_version &&
    exit 0
echo


if ! test -r "$BASEDIR/bin/start-vnc.sh"; then
    verb "use '<system>-start-vnc' script"
    false ||
        fail "Wrong current working directory."
fi


set_default_ports() {
    # Set default port if neither '$TUNNEL_PORT' nor one of '(R|L)PORT' is set.
    if test -z "$TUNNEL_PORT" && test -z "$RPORT" -o -z "$LPORT"; then
        case "$arg_command" in
            "viewer")
                RPORT=5500
                LPORT=5500
                ;;
            "server")
                RPORT=5900
                LPORT=5900
                ;;
            # Can't happen.
            *)
                RPORT=0000
                LPORT=0000
                ;;
        esac
    fi
}

print_hostspec() {
    local tunel_rl

    test -n "$RPORT$LPORT" &&
        tunel_rl="::"
    echo "$SSH_USER${SSH_USER:+"@"}$SSH_HOST${SSH_PORT:+":"}$SSH_PORT${TUNNEL_PORT:+::}$TUNNEL_PORT$tunel_rl$RPORT$tunel_rl$LPORT"
}

# Read host specification (user@host:port::<tunnelspec>) using readline.
read_hostspec() {
    local -n _hostspec="$1"
    read -e -i "${_hostspec:-`print_hostspec`}" -p "Please enter host: " _hostspec
    if test -z "$_hostspec"; then
        warn "No host defined."
        return 1
    fi
    history -s "$_hostspec"
}

# Parse host specification (user@host:port[::<tunnelspec>]).
parse_hostspec() {
    local hostspec="$1"
    local ssh_user="$SSH_USER"
    local ssh_host="$SSH_HOST"
    local ssh_port="$SSH_PORT"
    local rport="$RPORT"
    local lport="$LPORT"

    # Support '::<tunnelspec>' syntax.
    if [[ $hostspec =~ ::([[:digit:]]+)(::([[:digit:]]+)?)?$ ]]; then
        rport="${BASH_REMATCH[1]}"
        if test -n "${BASH_REMATCH[2]}"; then
            lport="${BASH_REMATCH[3]}"
            test -n "$lport" ||
            lport="$rport"
        fi
        hostspec="${hostspec%%::*}"
    fi
    if [[ $hostspec =~ ::.* ]]; then
        warn "Invalid <tunnelspec> syntax: '${BASH_REMATCH[0]}'"
        return 1
    fi

    # Get SSH user.
    if [[ $hostspec =~ ^([^@]*)@(.*) ]]; then
        ssh_user="${BASH_REMATCH[1]}"
        hostspec="${BASH_REMATCH[2]}"
    fi
    # Get SSH port.
    if [[ $hostspec =~ ([^:]*):(.*) ]]; then
        ssh_port="${BASH_REMATCH[2]}"
        hostspec="${BASH_REMATCH[1]}"
    fi
    #Get SSH host.
    test -n "$hostspec" &&
        ssh_host="$hostspec"

    if test -z "$ssh_user"; then
        warn "<user> not set."
        return 1
    fi
    if test -z "$ssh_host"; then
        warn "<host> not set."
        return 1
    fi
    if ! [[ $ssh_port =~ ^[[:digit:]]+$ ]]; then
        warn "Invalid <port>: '$ssh_port'"
        return 1
    fi

    SSH_USER="$ssh_user"
    SSH_HOST="$ssh_host"
    SSH_PORT="$ssh_port"
    RPORT="$rport"
    LPORT="$lport"
    debug "Parsed hostspec: `print_hostspec`"
    return 0
}

tunnel() {
    local vnc_conf="$1"
    shift

    verb "Creating SSH tunnel to '$SSH_USER@$SSH_HOST:$SSH_PORT' ($@) ..." &&
    while ! $D ssh_tunnel "$SSH_USER@$SSH_HOST" "$vnc_conf" -p "$SSH_PORT" "$@"; do
        sleep $RESTART_DELAY
    done
}

connect() {
    verb "Waiting for response from SSH server ..." &&
    ssh_connect -p "$SSH_PORT" "$@" "$SSH_USER@$SSH_HOST" "true"
}


vncviewer_mux() {
    local cmd="$1"
    local port="$2"
    shift 2
    local variant
    local binary

    binary="`lookup_binary "${vncviewer_variants[@]}" `" ||
    fail "Failed to locate VNC server."
    # Autodetect actual variant.
    if test "$binary" = "vncviewer"; then
        if "$binary" --version 2>&1 | grep -i "tiger"; then
            variant="xtigervncviewer"
        elif "$binary" --version 2>&1 | grep -i "tight"; then
            variant="xtightvncviewer"
        else
            fail "Failed to autodetect variant of '$binary'."
        fi
        verb "Using '$binary/$variant' as VNC viewer."
    else
        variant="$binary"
        verb "Using '$binary' as VNC viewer."
    fi

    case "$cmd" in
        "LISTEN")
            verb "Starting VNC viewer in listen mode (:$port) ..."
            case "$variant" in
                "xtightvncviewer")
                    $D "$binary" "$@" -listen $(($port - 5500))
                    ;;
                "xtigervncviewer"|\
                "vncviewer.exe")
                    $D "$binary" "$@" -listen "$port" >/dev/null
                    ;;
                *)
                    false ||
                    fail "Unsupported VNC viewer '$variant'."
                    ;;
            esac
            ;;
        "CONNECT")
            verb "Starting VNC viewer and connect to :$port ..."
            case "$variant" in
                "xtightvncviewer")
                    $D "$binary" "$@" "localhost::$port"
                    ;;
                "xtigervncviewer"|\
                "vncviewer.exe")
                    $D "$binary" "$@" "localhost:$port" >/dev/null
                    ;;
                 *)
                    false ||
                    fail "Unsupported VNC viewer '$variant'."
                    ;;
            esac
            ;;
        *)
            false ||
            fail "Invalid command: '$cmd'"
            ;;
    esac
}

vncserver_mux() {
    local cmd="$1"
    local port="$2"
    shift 2
    local timeout=$((RESTART_DELAY * 2))
    local variant
    local binary

    binary="`lookup_binary "${vncserver_variants[@]}"`" ||
        fail "Failed to locate VNC server."
    verb "Using '$binary' as VNC server."
    variant="$binary"

    case "$cmd" in
        "LISTEN")
            verb "Starting VNC server in listen mode (:$port) ..."
            case "$variant" in
                "x11vnc")
                    $D "$binary" -localhost -display :0 -nevershared -nopw  -quiet -once -timeout "$timeout" -rfbport "$port" "$@"
                    ;;
                "winvnc4")
                    $D "$binary" -LocalHost -PortNumber "$port" -SecurityTypes None -MaxDisconnectionTime "$timeout" "$@"
                    ;;
                *)
                    false ||
                    fail "Unsupported VNC server '$variant'."
                    ;;
            esac
            ;;
        "CONNECT")
            verb "Starting VNC server and connect to :$port ..."
            case "$variant" in
                "x11vnc")
                    $D "$binary" -localhost -display :0 -nevershared -nopw -quiet -once -timeout "$timeout" -connect_or_exit "localhost:$port" "$@"
                    ;;
                "winvnc4")
                    coproc $D "$binary" -LocalHost -SecurityTypes None -MaxDisconnectionTime "$timeout" "$@"
                    sleep $RESTART_DELAY
                    $D "$binary" -connect "localhost::$port" "$@"
                    wait
                    ;;
                *)
                    false ||
                    fail "Unsupported VNC server '$variant'."
                    ;;
            esac
            ;;
        *)
            false ||
            fail "Invalid command: '$cmd'"
            ;;
    esac
}

establish_ssh_gw() {
    test -n "$arg_ssh_gw" ||
    return 0

    # Use same ports as default.
    local RPORT="$SSH_PORT"
    local LPORT="$SSH_PORT"
    local SSH_USER="`whoami`"
    # Overwrite SSH_HOST.
    SSH_HOST=localhost
    local SSH_HOST
    local SSH_PORT=22

    parse_hostspec "$arg_ssh_gw" &&
    verb "Establishing SSH tunnel to SSH GW ..." &&
    if $do_listen; then
        tunnel false -R "$RPORT:localhost:$LPORT"
    else
        tunnel false -L "$LPORT:localhost:$RPORT"
    fi &&
    true ||
    fail "Failed to establish connection to SSH GW."
}

verify_cmd() {
    expected="$1"
    shift
    cmd="$1"
    port="$2"

    test $# -eq 2 ||
    error --err 1 "Wrong format of comand pipe, expected two arguments: `print_values_quoted "$@"`" || return $?
    case "$cmd" in
        "server"|\
        "viewer"|\
        "ANY")
            ;;
        *)
            false ||
            error "Invalid command: '$cmd'"
            ;;
    esac
    if test "$expected" != "ANY"; then
        test "$expected" = "$cmd" ||
        error "Expect command '$expected' but got '$cmd'."
    fi
    [[ "$port" =~ ^[[:digit:]]+$ ]] ||
    error "Invalid port: '$port'"
}

start_vnc() {
    local -A reziproc_cmd=(
        [server]=viewer
        [viewer]=server
        [ANY]=server/viewer
    )
    local rezi="${reziproc_cmd[$arg_command]}"
    local hostspec

    # Start SSH daemon.
    if $do_listen; then
        establish_ssh_gw &&
        $D sshd_listen "$SSH_PORT" "${arg_ssh[@]}" &&
        while true; do
            verb "Waiting for VNC $rezi to establish connection ..." &&
            cat "$CMD_PIPE" |
            while read -a line; do
                verify_cmd "$arg_command" "${line[@]}" || exit $?
                #FIXME: Wait for some to let listening VNC get started.
                sleep $RESTART_DELAY
                # Connect through tunnel.
                "vnc${line[0]}_mux" CONNECT "${line[1]}" "${arg_vnc[@]}" ||
                warn "No connection to VNC $rezi."
            done ||
            fail "Stopped listening for security reasons."
        done
    # Use SSH tunnel.
    else
        local hostspec
        # Initialise '$arg_hostspec' if not set by commandline.
        if test -z "$arg_hostspec"; then
            arg_hostspec="`print_hostspec`"
        else
            hostspec="$arg_hostspec"
        fi
        set_default_ports

        while true; do
            if test -z "$hostspec"; then
                hostspec="$arg_hostspec"
                read_hostspec "hostspec" ||
                continue
                arg_hostspec="$hostspec"
            fi &&
            if ! parse_hostspec "$hostspec"; then
                unset hostspec
                continue
            fi
            break
        done &&
        ssh_cache &&
        establish_ssh_gw &&
        while true; do
            local mark=`mark_cleanup`
            # Listen and establish tunnel.
            tunnel true -R "$RPORT:localhost:$LPORT" "${arg_ssh[@]}" &&
            while true; do
                #FIXME: It would be better to start listening VNC first asynchronously but check if it fails. As this is more complicated it is done the other way round.
                echo "$rezi" "$RPORT" | connect || {
                    warn "SSH connection lost."
                    break
                } &&
                "vnc${arg_command}_mux" LISTEN "$LPORT" "${arg_vnc[@]}" || {
                    warn "Failed to start VNC '$arg_command'."
                    # Force to review connection arguments.
                    unset hostspec
                    break
                }
                sleep $RESTART_DELAY
            done
            rewind_cleanup $mark
        done
    fi
}


# Let's the fun begin.

test -z "$arg_hostspec" ||
parse_hostspec "$arg_hostspec" ||
fail "Failed to parse <hostspec>."

history -r
push_cleanup history -w

trap "exit" SIGINT
case "$arg_command" in
    "server"|\
    "viewer"|\
    "ANY")
        start_vnc
        ;;
    *)
        test -n "$arg_command" ||
            fail "Missing <command>."
        false ||
            fail "Invalid <command> '$arg_command'."
        ;;
esac
