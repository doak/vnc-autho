#!/bin/bash

basedir="`realpath -e "$(dirname "$0")/.."`"
if test "$basedir" = "/"; then
    basedir=""
    name="vnc-autho"
else
    name="`basename "$basedir"`"
fi
kind="zip"
LL_default=2

source "$basedir/bin/tools.bash" ||
fail "Failed to source files."


syntax() {
    cat << EOF
SYNTAX: $0 [--help] [--compression <type>] [-- <archive-args>]
    -h|--help           Show this help.
    -z|--compression    Select archive type.

    <type>              zip|<tar-archive>
    <tar-archive>       Any archive type which is supported by tar (e.g. 'gz', 'bz2' or 'xz').
    <archive-args>      Additional arguments passed to archiver.

    Generate an archive (defaults to 'zip') of necessary files including SSH key-pair.
EOF
}

while test -n "$1"; do
    case "$1" in
        "-h"|"--help")
            syntax
            exit 0
            ;;
        "-z"|"--compress")
            kind="$2"
            shift
            ;;
        "--")
            shift
            break
            ;;
        *)
            fail "Unknown option: '$1'"
            ;;
    esac
    shift
done

create_archive() {
    local name="$1"
    local kind="$2"
    shift 2

    case "$kind" in
        "zip")
            create_zip "$name" "${name}_$VERSION.zip" "$@"
            ;;
        *)
            create_tar "$name" "$kind" "${name}_$VERSION.tar.$kind" "$@"
            ;;
    esac
}

create_tar() {
    local dir="$1"
    local kind="$2"
    local archive="$3"
    shift 3
    local -A kind_cmd=(
        [gz]="-z"
        [bz2]="-j"
        [xz]="-J"
    )

    local cmd="${kind_cmd[$kind]}"
    test -n "$cmd" ||
        fail "Do not know how to create archive '$archive'."

    verb "Creating archive '$archive' ..." &&
        tar --exclude-vcs --exclude="$dir/$dir*" --exclude="$dir/etc/hostspec.history" --exclude="$dir/add-on/key*" --exclude="$dir/etc/ssh_host*" --exclude="$dir/*.swp" "$cmd" -cvf "../$archive" -C .. "$@" "$dir" &&
        mv "../$archive" .
}

create_zip() {
    local dir="$1"
    local archive="$2"
    shift 2

    verb "Creating archive '$archive' ..." &&
        (
            cd .. &&
            rm -f "$dir/$archive" &&
            zip -r --exclude="$dir/.git/*" --exclude="$dir/$dir*" --exclude="$dir/etc/hostspec.history" --exclude="$dir/add-on/key*" --exclude="$dir/etc/ssh_host*" --exclude="*.swp" "$@" "$dir/$archive" "$dir"
        )
}

read_version() {
    if ! test -f "$VERSION_FILE"; then
        ./bin/start-vnc.sh --create-version-file &&
            push_cleanup rm -f "$VERSION_FILE" "$PATCH_FILE" ||
            exit $?
    fi &&
    source "$VERSION_FILE" &&
    if test -r "$CONFIG_FILE"; then
        source "$CONFIG_FILE"
    fi &&
    test -n "$VERSION" &&
    VERSION="`echo "$CONFIG${CONFIG:+-}$VERSION" | sed 's/-0-g[[:xdigit:]]\+//'`" &&
    true
}


cd "$basedir" ||
    fail

verb "Checking setup ..." &&
    ./bin/check-setup.sh ||
    fail "Failed to check setup."

read_version &&
    create_archive "$name" "$kind" "$@" ||
    fail "Failed to create archive for '$name'."
