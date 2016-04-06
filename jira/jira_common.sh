THIS=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Include helpers

. ${THIS}/../helpers.sh

. $CONFIG_FILE

test -z "$JIRA_PATH" && fail "JIRA_PATH not set"
export JIRA_BASE="$JIRA_PATH"
test -z "$JIRA_USER" && fail "JIRA_USER not set"
test -z "$JIRA_TYPE" && export JIRA_TYPE="jira-core"
test -z "$JIRA_SERVICE_NAME" && export JIRA_SERVICE_NAME="jira"
test -d "$JIRA_BASE" || fail "${JIRA_BASE} is not a directory"
test -z "$DEBUG" && export DEBUG=0

export JIRA_BASE
export JIRA_USER
export JIRA_TYPE

if [ "$DEBUG" = "1" ]
then
    export DEBUG="$DEBUG"
else
    export DEBUG="0"
fi

export JIRA_CURRENT="${JIRA_BASE}/current"

test -h ${JIRA_CURRENT} || fail "${JIRA_CURRENT} is not link"

# Previous jira directory
readlink "${JIRA_CURRENT}" > /dev/null 2>&1 || fail "${JIRA_CURRENT} is a broken link"
export JIRA_PREVIOUS="$(readlink -f ${JIRA_CURRENT})"

# Get jira version
export JIRA_BANNER="$(find "$JIRA_PREVIOUS" -name jirabanner.txt)"
test -z "$JIRA_BANNER" && fail "Cannot get JIRA version"

export JIRA_VERSION=$(cat ${JIRA_BANNER} |sed -n -e 's/.*Version.*: \([0-9\.]*\)\r/\1/p')

test -z "$JIRA_VERSION" && fail "Failed to fetch JIRA version from ${JIRA_BANNER}"

export BACKUPDIR="${BACKUPDIR:-$(realpath ${JIRA_BASE}/backup)}"

export BINBACKUPDIR="$(realpath ${BACKUPDIR}/binary)"

export APPLICATIONDATABACKUPDIR="$(realpath ${BACKUPDIR}/application-data)"

export APPLICATION_DATA_DIR="$(get_init_value ${JIRA_PREVIOUS}/atlassian-jira/WEB-INF/classes/jira-application.properties jira.home)"

# Get database variables, bash </3 XML
export JIRA_DATABASE_USERNAME="$(cat ${APPLICATION_DATA_DIR}/dbconfig.xml | sed -ne 's/.*<username>\(.*\)<\/username>.*/\1/p')"
export JIRA_DATABASE_PASSWORD="$(cat ${APPLICATION_DATA_DIR}/dbconfig.xml | sed -ne 's/.*<password>\(.*\)<\/password>.*/\1/p')"
export JIRA_DATABASE_URI="$(cat ${APPLICATION_DATA_DIR}/dbconfig.xml | sed -ne 's/.*<url>\(.*\)<\/url>.*/\1/p')"
export JIRA_DATABASE_SERVER="$(echo $JIRA_DATABASE_URI |sed  -ne 's/.*:\/\/\(.*\):.*/\1/p')"
export JIRA_DATABASE_PORT="$(echo $JIRA_DATABASE_URI |sed  -ne 's/.*:\/\/.*:\(.*\)\/.*/\1/p')"
export JIRA_DATABASE_NAME="$(echo $JIRA_DATABASE_URI |sed  -ne 's/.*:\/\/.*:.*\/\(.*\)$/\1/p')"

test -z "$JIRA_DATABASE_USERNAME" && fail "Failed to get database username for JIRA from ${APPLICATION_DATA_DIR}/dbconfig.xml"
test -z "$JIRA_DATABASE_PASSWORD" && fail "Failed to get database password for JIRA from ${APPLICATION_DATA_DIR}/dbconfig.xml"
test -z "$JIRA_DATABASE_SERVER" && fail "Failed to get database server address for JIRA from ${APPLICATION_DATA_DIR}/dbconfig.xml"
test -z "$JIRA_DATABASE_PORT" && fail "Failed to get database server port for JIRA from ${APPLICATION_DATA_DIR}/dbconfig.xml"
test -z "$JIRA_DATABASE_NAME" && fail "Failed to get database name for JIRA from ${APPLICATION_DATA_DIR}/dbconfig.xml"

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


function backup_jira() {
    test -f "${JIRA_PREVIOUS}/atlassian-jira/WEB-INF/classes/jira-application.properties" || fail "${JIRA_PREVIOUS}/atlassian-jira/WEB-INF/classes/jira-application.properties not such file"

    test -d "${BACKUPDIR}" || ( mkdir "${BACKUPDIR}"; chmod 700 "${BACKUPDIR}" )

    backup_database "jira-${JIRA_VERSION}.sql"

    
    #test -d "${BINBACKUPDIR}" || ( mkdir "${BINBACKUPDIR}"; chmod 700 "${BINBACKUPDIR}" )
    test -d "${APPLICATIONDATABACKUPDIR}" || ( mkdir "${APPLICATIONDATABACKUPDIR}"; chmod 700 "${APPLICATIONDATABACKUPDIR}" )

    # Skip for now
    #backup_files "${JIRA_PREVIOUS}" "${BINBACKUPDIR}"

    backup_files "${APPLICATION_DATA_DIR}" "${APPLICATIONDATABACKUPDIR}"

}
