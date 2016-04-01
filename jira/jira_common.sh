THIS=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Include helpers

. ${THIS}/../helpers.sh

. $CONFIG_FILE

export JIRA_BASE
export JIRA_USER
export JIRA_TYPE
#export ATLASSIAN_BASE=/opt/jira

#export JIRA_BASE="$(realpath ${ATLASSIAN_BASE}/jira)/"

test -z "$JIRA_PATH" && fail "JIRA_PATH not set"
export JIRA_BASE="$JIRA_PATH"
test -z "$JIRA_USER" && fail "JIRA_USER not set"
test -z "$JIRA_TYPE" && export JIRA_TYPE="jira-core"

test -d "$JIRA_BASE" || fail "${JIRA_BASE} is not a directory"

export JIRA_CURRENT="${JIRA_BASE}/current"

test -h ${JIRA_CURRENT} || fail "${JIRA_CURRENT} is not link"

# Previous jira directory
readlink "${JIRA_CURRENT}" || fail "${JIRA_CURRENT} is a broken link"
export JIRA_PREVIOUS="$(readlink -f ${JIRA_CURRENT})"

# Get jira version
export JIRA_BANNER="$(find "$JIRA_PREVIOUS" -name jirabanner.txt)"
test -z "$JIRA_BANNER" && fail "Cannot get JIRA version"

export JIRA_VERSION=$(cat ${JIRA_BANNER} |sed -n -e 's/.*Version.*: \([0-9\.]*\)\r/\1/p')

export BACKUPDIR="${BACKUPDIR:-$(realpath ${JIRA_BASE}/backup)}"

export BINBACKUPDIR="$(realpath ${BACKUPDIR}/binary)"

export APPLICATIONDATABACKUPDIR="$(realpath ${BACKUPDIR}/application-data)"

export APPLICATION_DATA_DIR="$(cat ${JIRA_PREVIOUS}/atlassian-jira/WEB-INF/classes/jira-application.properties |awk -F '= ' '$1 ~ /jira.home.*/  { print $2 }')"

export JIRA_DATABASE_USERNAME="$(cat ${APPLICATION_DATA_DIR}/dbconfig.xml | sed -ne 's/.*<username>\(.*\)<\/username>.*/\1/p')"
export JIRA_DATABASE_PASSWORD="$(cat ${APPLICATION_DATA_DIR}/dbconfig.xml | sed -ne 's/.*<password>\(.*\)<\/password>.*/\1/p')"
export JIRA_DATABASE_URI="$(cat ${APPLICATION_DATA_DIR}/dbconfig.xml | sed -ne 's/.*<url>\(.*\)<\/url>.*/\1/p')"
export JIRA_DATABASE_SERVER="$(echo $JIRA_DATABASE_URI |sed  -ne 's/.*:\/\/\(.*\):.*/\1/p')"
export JIRA_DATABASE_PORT="$(echo $JIRA_DATABASE_URI |sed  -ne 's/.*:\/\/.*:\(.*\)\/.*/\1/p')"
export JIRA_DATABASE_NAME="$(echo $JIRA_DATABASE_URI |sed  -ne 's/.*:\/\/.*:.*\/\(.*\)$/\1/p')"


# Backup
function backup_database() {
    filename=$1
    test -z "$filename" && fail "Dump filename cannot be empty"
    info "Backupping database ${JIRA_DATABASE_NAME} to ${BACKUPDIR}/${filename}.gz"
    BACKUP_FILE="${BACKUPDIR}/${filename}.gz"
    touch "${BACKUP_FILE}"
    chmod 600 "${BACKUP_FILE}"
    export PGPASSWORD="$JIRA_DATABASE_PASSWORD"
    export PGPORT="$JIRA_DATABASE_PORT"
    export PGHOST="$JIRA_DATABASE_SERVER"
    export PGUSER="$JIRA_DATABASE_USERNAME"
    pg_dump $JIRA_DATABASE_NAME |gzip -c > "${BACKUP_FILE}"
    chmod 600 "${BACKUP_FILE}"
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
    rsync -aHAX --delete "$sourcedir" "${destdir}/"

}

function backup_jira() {
    test -f "${JIRA_PREVIOUS}/atlassian-jira/WEB-INF/classes/jira-application.properties" || fail "${JIRA_PREVIOUS}/atlassian-jira/WEB-INF/classes/jira-application.properties not such file"

    backup_database "jira-${JIRA_VERSION}.sql"

    test -d "${BACKUPDIR}" || ( mkdir "${BACKUPDIR}"; chmod 700 "${BACKUPDIR}" )
    test -d "${BINBACKUPDIR}" || ( mkdir "${BINBACKUPDIR}"; chmod 700 "${BINBACKUPDIR}" )
    test -d "${APPLICATIONDATABACKUPDIR}" || ( mkdir "${APPLICATIONDATABACKUPDIR}"; chmod 700 "${APPLICATIONDATABACKUPDIR}" )

    # Skip for now
    #backup_files "${JIRA_PREVIOUS}" "${BINBACKUPDIR}"

    backup_files "${APPLICATION_DATA_DIR}" "${APPLICATIONDATABACKUPDIR}"

}
