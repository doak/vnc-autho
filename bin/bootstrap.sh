#!/bin/bash

PATH="bin:$PATH"


stamp_busybox="./bin/.bootstraped_busybox"
stamp_mandatory="./bin/.bootstraped_wintools"

bootstrap_busybox() {
    local ok=true

    test -e "$stamp_busybox" &&
    return 0

    echo "Bootstraping 'busybox' ..." >&2
    for link in `busybox --list`; do
        busybox ln -sf "busybox.exe" "./bin/$link.exe" || {
            ok=false
            break
        }
    done
    $ok &&
    touch "$stamp_busybox"
}

bootstrap_mandatory() {
    test -e "$stamp_mandatory" &&
    return 0

    echo "Extracting mandatory tools for Windows ..." >&2
    add-on.sh add "./add-on/win_"* &&
    ln -sf "procps.exe" "./bin/ps.exe" &&
    echo "Prepare sshd ..." >&2 &&
    mkdir -p "./var/empty" &&
    touch "$stamp_mandatory"
}


bootstrap_busybox &&
bootstrap_mandatory &&
true
