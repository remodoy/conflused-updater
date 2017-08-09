THIS=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Include helpers

. ${THIS}/../helpers.sh

. $CONFIG_FILE

test -z "$DEBUG" && export DEBUG=0

if [ "$DEBUG" = "1" ]
then
    export DEBUG="$DEBUG"
else
    export DEBUG="0"
fi

if [ "$DEBUG" = "1" ]
then
    # set -x when debug
    set -x
fi

which realpath > /dev/null || fail "realpath not installed"

test -z "$CROWD_PATH" && fail "CROWD_PATH not set"
test -e "$CROWD_PATH" || fail "Directory $CROWD_PATH does not exist"
export CROWD_BASE="$(realpath $CROWD_PATH)"
test -z "$CROWD_USER" && fail "CROWD_USER not set"
test -z "$CROWD_SERVICE_NAME" && export CROWD_SERVICE_NAME="crowd"
test -d "$CROWD_BASE" || fail "${CROWD_BASE} is not a directory"


export CROWD_BASE
export CROWD_USER


export CROWD_CURRENT="${CROWD_BASE}/current"

test -h ${CROWD_CURRENT} || fail "${CROWD_CURRENT} is not a symbolic link"

# Previous crowd directory
readlink "${CROWD_CURRENT}" > /dev/null 2>&1 || fail "${CROWD_CURRENT} is a broken link"
export CROWD_PREVIOUS="$(readlink -f ${CROWD_CURRENT})"

# Previous crowd version
export CROWD_BANNER="${CROWD_PREVIOUS}/README.txt"
test -z "$CROWD_BANNER" && fail "Cannot get CROWD version"

export CROWD_VERSION=$(cat ${CROWD_BANNER} |sed -n -e 's/.*Atlassian Crowd \([0-9\.]*\)\r/\1/p' | head -n 1)

test -z "$CROWD_VERSION" && fail "Failed to fetch CROWD version from ${CROWD_BANNER}"

export BACKUPDIR="${BACKUPDIR:-${CROWD_BASE}/backup}"

export BINBACKUPDIR="${BACKUPDIR}/binary"

export APPLICATIONDATABACKUPDIR="${BACKUPDIR}/application-data"

export APPLICATION_DATA_DIR="$(get_init_value ${CROWD_PREVIOUS}/crowd-webapp/WEB-INF/classes/crowd-init.properties crowd.home)"

export CROWD_DATABASE_CONFIG_FILE=" ${APPLICATION_DATA_DIR}/crowd.cfg.xml"

# Get database variables, bash </3 XML
export CROWD_DATABASE_USERNAME="$(cat ${CROWD_DATABASE_CONFIG_FILE} | sed -ne 's/.*<property name="hibernate.connection.username">\(.*\)<\/property>.*/\1/p')"
export CROWD_DATABASE_PASSWORD="$(cat ${CROWD_DATABASE_CONFIG_FILE} | sed -ne 's/.*<property name="hibernate.connection.password">\(.*\)<\/property>.*/\1/p')"
export CROWD_DATABASE_URI="$(cat ${CROWD_DATABASE_CONFIG_FILE} | sed -ne 's/.*<property name="hibernate.connection.url">\(.*\)<\/property>.*/\1/p')"
export CROWD_DATABASE_TYPE="$(echo $CROWD_DATABASE_URI |sed  -ne 's/^jdbc:\([a-z][a-z]*\):\/\/.*/\1/p')"
export CROWD_DATABASE_SERVER="$(echo $CROWD_DATABASE_URI |sed  -ne 's/.*:\/\/\(.*\):.*/\1/p')"
export CROWD_DATABASE_PORT="$(echo $CROWD_DATABASE_URI |sed  -ne 's/.*:\/\/.*:\(.*\)\/.*/\1/p')"
export CROWD_DATABASE_NAME="$(echo $CROWD_DATABASE_URI |sed  -ne 's/.*:\/\/.*:.*\/\(.*\)$/\1/p')"

# Test database is postgresql database
test "$CROWD_DATABASE_TYPE" = "postgresql" || fail "Only postgresql database currently supported"

test -z "$CROWD_DATABASE_USERNAME" && fail "Failed to get database username for CROWD from ${CROWD_DATABASE_CONFIG_FILE}"
test -z "$CROWD_DATABASE_PASSWORD" && fail "Failed to get database password for CROWD from ${CROWD_DATABASE_CONFIG_FILE}"
test -z "$CROWD_DATABASE_SERVER" && fail "Failed to get database server address for CROWD from ${CROWD_DATABASE_CONFIG_FILE}"
test -z "$CROWD_DATABASE_PORT" && fail "Failed to get database server port for CROWD from ${CROWD_DATABASE_CONFIG_FILE}"
test -z "$CROWD_DATABASE_NAME" && fail "Failed to get database name for CROWD from ${CROWD_DATABASE_CONFIG_FILE}"

if [ "$DEBUG" = "1" ]
then
    echo "Environment:"
    env
fi

# Backup
function backup_database() {
    filename=$1
    test -z "$filename" && fail "Dump filename cannot be empty"
    info "Backupping database ${CROWD_DATABASE_NAME} to ${BACKUPDIR}/${filename}.gz"
    BACKUP_FILE="${BACKUPDIR}/${filename}.gz"
    touch "${BACKUP_FILE}"
    chmod 600 "${BACKUP_FILE}"
    export PGPASSWORD="$CROWD_DATABASE_PASSWORD"
    export PGPORT="$CROWD_DATABASE_PORT"
    export PGHOST="$CROWD_DATABASE_SERVER"
    export PGUSER="$CROWD_DATABASE_USERNAME"
    pg_dump $CROWD_DATABASE_NAME |gzip -c > "${BACKUP_FILE}"
    chmod 600 "${BACKUP_FILE}"
}


function backup_crowd() {
    test -f "${CROWD_PREVIOUS}/crowd-webapp/WEB-INF/classes/crowd-init.properties" || fail "${CROWD_PREVIOUS}/crowd-webapp/WEB-INF/classes/crowd-init.properties not such file"

    test -d "${BACKUPDIR}" || ( mkdir "${BACKUPDIR}"; chmod 700 "${BACKUPDIR}" )

    backup_database "crowd-${CROWD_VERSION}.sql"

    
    #test -d "${BINBACKUPDIR}" || ( mkdir "${BINBACKUPDIR}"; chmod 700 "${BINBACKUPDIR}" )
    test -d "${APPLICATIONDATABACKUPDIR}" || ( mkdir "${APPLICATIONDATABACKUPDIR}"; chmod 700 "${APPLICATIONDATABACKUPDIR}" )

    # Skip for now
    #backup_files "${CROWD_PREVIOUS}" "${BINBACKUPDIR}"

    backup_files "${APPLICATION_DATA_DIR}" "${APPLICATIONDATABACKUPDIR}"

}
