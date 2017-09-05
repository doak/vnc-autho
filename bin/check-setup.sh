#!/bin/bash

basedir="`dirname "$0"`/.."
always_fix=false
success=true
LL_default=2

ssh_default_port=2222
f_conf="etc/host.conf"
f_ssh_ckey="etc/ssh_key"
f_ssh_hkey="etc/ssh_host_ecdsa_key"
f_ssh_known="etc/ssh_known_hosts"
f_ssh_author="etc/ssh_authorized_keys"

source "$basedir/bin/lib-bash/log"
source "$basedir/bin/tools.bash"


syntax() {
    cat << EOF
SYNTAX: "$0" [-h|--help] [-f|--fix]
EOF
}

while test -n "$1"; do
    case "$1" in
        "-h"|"--help")
            syntax
            exit 0
            ;;
        "-f"|"--fix")
            always_fix=true
            ;;
        *)
            false ||
                fail "Unknown option: '$1'"
            ;;
    esac
    shift
done


fix_it() {
    local REPLY
    local description="$1"
    shift
    local rhs=("$@")
    local success=true

    (
        echo -n "$description [y/N] "
        $always_fix &&
            { REPLY="y"; echo; } ||
            read REPLY
        if test "$REPLY" = "Y" -o "$REPLY" = "y"; then
            while test ${#rhs[@]} -gt 0; do
                split_array lhs rhs ";" "${rhs[@]}" &&
                    "${lhs[@]}" >&3 || {
                        success=false
                        break
                    }
            done
            $success &&
                verb "fixed"
        else
            false
        fi
    ) 3>&1 >&2
}


cd "$basedir" ||
    fail

if ! test -f "$f_conf" ; then
    fix_it "Create missing host configuration '$f_conf'?" bash -c "echo -e 'SSH_HOST=\nSSH_USER=\"`whoami`\"\nSSH_PORT=$ssh_default_port\n' >'$f_conf'" ||
    success=false

fi
if $success; then
    source "$f_conf"
    if test -z "$SSH_HOST"; then
        warn "Missing default IP/DNS for host in '$f_conf'."
    fi
    if test -z "$SSH_PORT"; then
        warn "Missing default port for host in '$f_conf'."
    fi
    if test -z "$SSH_USER"; then
        warn "Missing default user for host in '$f_conf'."
    fi
fi

if ! test -r "$f_ssh_hkey" -a -r "$f_ssh_hkey.pub"; then
    warn "SSH host keypair is missing ('$f_ssh_hkey' and/or '$f_ssh_hkey.pub')."
    fix_it "Generate a new SSH keypair?" ssh-keygen -N "" -t ecdsa -f "$f_ssh_hkey"
elif test "`stat --format=%a "$f_ssh_hkey"`" != 600; then
    warn "Wrong permissions for private SSH host key ('$f_ssh_hkey')."
    fix_it "Fix permissions of private key?" chmod 600 "$f_ssh_hkey" ||
    success=false
fi

fix_known_hosts() {
        local file="$1"
        local do_header=false

        test -f "$file"||
            do_header=true

        (
            if $do_header; then
                echo "# Add your host fingerprint with '*' wildcard as hostname to allow changing hostname/IP address."
                echo
            fi
            echo "# Host configured by '`whoami`@`hostname`':"
            sed 's/^/* /' "$f_ssh_hkey.pub"
        ) >>"$file"
}
if test -e "$f_ssh_hkey.pub"; then
    if ! test -r "$f_ssh_known" || ! sed "s/= .*/=/" "$f_ssh_hkey.pub" | grep -wFf - "$f_ssh_known" >/dev/null; then
        warn "The current public SSH host key ('$f_ssh_hkey.pub') is not configured."
        fix_it "Do you want to add the available public SSH host key to ('$f_ssh_known')?" fix_known_hosts "$f_ssh_known" ||
        success=false
    fi
else
    warn "Skipped check of '$f_ssh_known' because there is no public SSH host key."
    sucess=false
fi

if ! test -r "$f_ssh_ckey" -o -r "$f_ssh_ckey.pub"; then
    warn "SSH client keypair is missing ('$f_ssh_ckey' and/or '$f_ssh_ckey.pub')."
    verb "It is recommended to use a keypair instead of credential to get access to your host."
    fix_it "Generate a new SSH keypair?" \
        warn "ALWAYS use a passphrase to protect the private key! Virus scanners etc. on remote PC are usually configured to upload data to foreign server for example." \; \
        ssh-keygen -f "$f_ssh_ckey"
elif test "`stat --format=%a "$f_ssh_ckey"`" != 600; then
    warn "Wrong permissions for private SSH client key ('$f_ssh_ckey')."
    fix_it "Fix permissions of private key?" chmod 600 "$f_ssh_ckey" ||
    success=false
fi

if ! test -r "$f_ssh_author" || test "`cat "$f_ssh_author" | wc -l`" -eq 0; then
    warn "It seems there is not a single client configured to connect ('$f_ssh_author')."
    fix_it "Allow the current client public key ('etc/ssh_key.pub') to connect?" bash -c "cat 'etc/ssh_key.pub' >>'etc/ssh_authorized_keys'" ||
    success=false
fi

$success
