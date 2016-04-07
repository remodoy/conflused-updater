function info() {
    echo "Info: $@"
}

function fail() {

    echo "Failed: $@"
    exit 1
}

function test_variable() {
    NAME="$1"
    test -z "${!NAME}" && fail "Variable $NAME not set" || true
}

function get_init_value() {
    FILE="$1"
    VALUE="$2"
    test -f "$FILE" || fail "Not such file or directory '$FILE'"
    cat "$FILE" |awk -v search="^${VALUE}.*" -F '=' '{ if (match ($1, search)) { gsub(/ /, "", $0); gsub(/\r/, "", $0); print $2 } }'
}

function servicemanager() {
    service="$1"
    action="$2"
    test -z $service && fail "service must be given"
    test -z $action && fail "action must be given"
    export SUDO=""
    [ "$(whoami)" != "root" ] && export SUDO="sudo"
    # Systemctl
    which systemctl > /dev/null 2>&1 && $SUDO systemctl "$action" "$service" && return 0
    # Init.d
    test -f /etc/init.d/$service && $SUDO /etc/init.d/$service "$action" && return 0
    # service
    which service > /dev/null 2>&1 && $SUDO service "$service" "$action" && return 0
}

function backup_files() {
    sourcedir=$1
    destdir=$2
    test -z "$sourcedir" && fail "Backup source dir cannot be empty"
    test -z "$destdir" && fail "Backup destination dir cannot be empty"
    test -d "$sourcedir" || fail "Backup source dir does not exist"
    sourcedir="${sourcedir%/}"
    destdir="${destdir%/}"
    info "Backupping $sourcedir to ${destdir}/"
    rsync -aHAX --exclude backups/ --exclude export/ --delete "$sourcedir" "${destdir}/"

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
    # Backup distributed version and copy old configuration
    mv "$new" "${new}.dist"
    cp "$old" "$new"
    true
}

function latest_version_url() {
	if [ -z "$1" ]
	then
		echo "Error: Invalid number of options in lastest_version()" 1>&2
		exit 1
	fi
	software="$(echo $1 | tr '[:upper:]' '[:lower:]')"
	wget -qO-  "https://my.atlassian.com/download/feeds/current/${software}.json" |sed -e 's/.*\(https:\/\/.*\.tar.gz\).*/\1/'
}

function latest_version() {
	if [ -z "$1" ]
	then
		echo "Error: Invalid number of options in lastest_version()" 1>&2
		exit 1
	fi
	software="$(echo $1 | tr '[:upper:]' '[:lower:]')"
	wget -qO-  "https://my.atlassian.com/download/feeds/current/${software}.json" |sed -e 's/.*"version":"\([0-9][0-9\.]*\)",".*/\1/' | head
}

# http://stackoverflow.com/questions/4023830/bash-how-compare-two-strings-in-version-format
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}