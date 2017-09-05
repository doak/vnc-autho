test -n "$TOOLS_BASH" &&
    exit ||
    TOOLS_BASH="done"

bindir="`dirname "${BASH_SOURCE[0]}"`" &&
source "$bindir/fail.bash" &&
source "$bindir/lib-bash/log" &&
source "$bindir/lib-bash/args" &&
source "$bindir/lib-bash/tools" &&
true ||
fail "Failed to 'lib-bash'."


# FIXME Consolidate with 'split_at_seperator()' of lib-bash.
# Split array into two parts, the first part upto an marker and the (opional) remaining part.
split_array() {
    local -n xx_lhs="$1"
    local -n xx_rhs="$2"
    local marker="$3"
    shift 3

    xx_lhs=()
    while test $# -gt 0 -a "$1" != "$marker"; do
        xx_lhs+=("$1")
        shift
    done
    shift
    xx_rhs=("$@")
}

# Set variable to true or false based on option string.
set_flag() {
    local option_string="$1"
    local name="${option_string//-/_}"

    case "$option_string" in
        "--no-"*)
            local -n option="do_${name:5}"
            option=false
            ;;
        "--"*)
            local -n option="do_${name:2}"
            option=true
            ;;
        *)
            fail "Invalid option: '$option_string'"
            ;;
    esac
}

# Extract version information from Git or "$VERSION_FILE" and stores it into variables '$VERSION' and '$DATE'. The patch to HEAD will be stored as well.
# If '$do_create_version_file' is set to 'true', file '$VERSION_FILE'  and '$PATCH_FILE' will be created.
VERSION_FILE=".version"
PATCH_FILE=".patch"
CONFIG_FILE=".config"
extract_version() {
    if test -f "$CONFIG_FILE"; then
        source "$CONFIG_FILE"
    fi
    if ! $do_create_version_file && test -f "$VERSION_FILE"; then
        source "$VERSION_FILE"
    else
        VERSION="`git describe --dirty --always --long`"
        DATE="`git show --pretty=%ci --no-patch`"
        echo "$VERSION" | grep -- "-dirty$" >/dev/null &&
            git diff --binary HEAD -- $(ls -AF | grep -v "^add-on/$") >"$PATCH_FILE"
    fi
    test -n "$VERSION" ||
        VERSION="n.a."
    test -n "$DATE" ||
        DATE="`date --iso-8601=seconds`"

    if $do_create_version_file; then
        cat >"$VERSION_FILE" <<EOF ||
VERSION='$VERSION'
DATE='$DATE'
EOF
            return $?
    fi
}

killtree() {
    local parent="$1"
    local pids=(`ps --no-headers -opid --ppid "$parent"`)

    debug CHILDS `print_values_quoted "${pids[@]}"`
    $D kill "$parent" 2>/dev/null
    for pid in "${pids[@]}"; do
        killtree "$pid"
    done
}
