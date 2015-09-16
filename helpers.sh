function info() {
    echo "Info: $@"
}

function fail() {

    echo "Failed: $@"
    exit 1
}

function servicemanager() {
    service="$1"
    action="$2"
    test -z $service && fail "service must be given"
    test -z $action && fail "action must be given"
    # Systemctl
    which systemctl > /dev/null 2>&1 && systemctl "$action" "$service" && return 0
    # Init.d
    test -f /etc/init.d/$service && /etc/init.d/$service "$action" && return 0
    # service
    which service > /dev/null 2>&1 && service "$service" "$action" && return 0
}

function restore_file() {
    path="$1"
    old_base="$2"
    new_base="$3"
    test -z "$old_base" && fail "Old base must be defined"
    test -z "$new_base" && fail "Old base must be defined"
    old="${old_base}/${path}"
    new="${new_base}/${path}"
    test -f "$old" || fail "Old file '$old' must exist"
    test -f "$new" && diff "$old" "$new" && true
    cp "$old" "$new"
    true
}