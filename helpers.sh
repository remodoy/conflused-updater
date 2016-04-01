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
    export SUDO=""
    [ "$(whoami)" != "root" ] && export SUDO="sudo"
    # Systemctl
    which systemctl > /dev/null 2>&1 && $SUDO systemctl "$action" "$service" && return 0
    # Init.d
    test -f /etc/init.d/$service && $SUDO /etc/init.d/$service "$action" && return 0
    # service
    which service > /dev/null 2>&1 && $SUDO service "$service" "$action" && return 0
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