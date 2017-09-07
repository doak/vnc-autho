fail() {
    local errcode=$?
    if test "$1" = "--err"; then
        errcode="$2"
        shift 2
    fi

    run_cleanup
    #FIXME: Why are both traps (here and in main script) neccessary? Please FIXME description in main script.
    trap "exit" SIGINT
    echo "ERR($errcode)${*:+": "}$@" >&2
    # Leave shell open in case of an error to inform unexperienced users.
    echo "Press [Return] to quit." >&2
    read -s
    exit $errcode
}
