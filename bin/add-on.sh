#!/bin/bash

# This script is needed to extract/copy basic functionality. Hence it has to be very simple and is only allowed to use a subset of bash (supported by 'busybox' for example).


basedir="`dirname "$0"`/.."
source "$basedir/bin/fail.bash"


cmd_add() {
    local archive="$1"

    ask "Extract" "$archive" ||
        return 0

    tar xf "$archive"
}

cmd_rm() {
    local archive="$1"

    ask "Remove" "$archive" ||
        return 0

    tar tf "$archive" | grep -v "/$" | while read f; do
        rm -f "$f"
    done
}

ask() {
    local text="$1"
    local archive="$2"

    $ASK ||
        return 0

    echo -n "$text add-on '$archive'? [y/N] "
    read REPLY
    test "$REPLY" = "Y" -o "$REPLY" = "y" &&
        return 0
    return 1
}


command="$1"
shift
case "$command" in
    "add"|"rm")
        ;;
    "")
        fail "Command is missing."
        ;;
    *)
        fail "Unknown command: '$command'"
        ;;
esac

cd "$basedir" ||
    fail "Unable to change to basedir."


ASK=false
test $# -eq 0 &&
    set -- `find "add-on" -type f -name "*.tar*"` &&
    ASK=true

for archive in "$@"; do
    cmd_$command "$archive"
done
