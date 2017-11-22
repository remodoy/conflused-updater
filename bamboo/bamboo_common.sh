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

test -z "$BAMBOO_PATH" && fail "BAMBOO_PATH not set"
test -e "$BAMBOO_PATH" || fail "Directory $BAMBOO_PATH does not exist"
export BAMBOO_BASE="$(realpath $BAMBOO_PATH)"
test -z "$BAMBOO_USER" && fail "BAMBOO_USER not set"
test -z "$BAMBOO_SERVICE_NAME" && export BAMBOO_SERVICE_NAME="bamboo"
test -d "$BAMBOO_BASE" || fail "${BAMBOO_BASE} is not a directory"

export BAMBOO_BASE
export BAMBOO_USER

export BAMBOO_CURRENT="${BAMBOO_BASE}/current"

test -h ${BAMBOO_CURRENT} || fail "${BAMBOO_CURRENT} is not a symbolic link"

# Previous Bamboo directory
readlink "${BAMBOO_CURRENT}" > /dev/null 2>&1 || fail "${BAMBOO_CURRENT} is a broken link"
export BAMBOO_PREVIOUS="$(readlink -f ${BAMBOO_CURRENT})"

# Get Bamboo version
export BAMBOO_BANNER="$(find "$BAMBOO_PREVIOUS" -name bamboobanner.txt)"
test -z "$BAMBOO_BANNER" && fail "Cannot get Bamboo version"

export BAMBOO_VERSION=$(cat ${BAMBOO_BANNER} |sed -n -e 's/.*Version.*: \([0-9\.]*\)\r/\1/p')

test -z "$BAMBOO_VERSION" && fail "Failed to fetch Bamboo version from ${BAMBOO_BANNER}"

export BACKUP_DIR="${BACKUP_DIR:-${BAMBOO_BASE}/backup}"

export BIN_BACKUP_DIR="${BACKUP_DIR}/binary"

export APPLICATION_DATA_BACKUP_DIR="${BACKUP_DIR}/application-data"

export APPLICATION_DATA_DIR="$(get_init_value ${BAMBOO_PREVIOUS}/atlassian-bamboo/WEB-INF/classes/bamboo-init.properties bamboo.home)"

# Get database variables, bash </3 XML
export BAMBOO_DATABASE_USERNAME="$(cat ${APPLICATION_DATA_DIR}/bamboo.cfg.xml | sed -ne 's/.*<property name="hibernate.connection.username">\(.*\)<\/property>.*/\1/p')"
export BAMBOO_DATABASE_PASSWORD="$(cat ${APPLICATION_DATA_DIR}/bamboo.cfg.xml | sed -ne 's/.*<property name="hibernate.connection.password">\(.*\)<\/property>.*/\1/p')"
export BAMBOO_DATABASE_URI="$(cat ${APPLICATION_DATA_DIR}/bamboo.cfg.xml | sed -ne 's/.*<property name="hibernate.connection.url">\(.*\)<\/property>.*/\1/p')"
export BAMBOO_DATABASE_TYPE="$(echo $BAMBOO_DATABASE_URI |sed  -ne 's/^jdbc:\([a-z][a-z]*\):\/\/.*/\1/p')"
export BAMBOO_DATABASE_SERVER="$(echo $BAMBOO_DATABASE_URI |sed  -ne 's/.*:\/\/\(.*\):.*/\1/p')"
export BAMBOO_DATABASE_PORT="$(echo $BAMBOO_DATABASE_URI |sed  -ne 's/.*:\/\/.*:\(.*\)\/.*/\1/p')"
export BAMBOO_DATABASE_NAME="$(echo $BAMBOO_DATABASE_URI |sed  -ne 's/.*:\/\/.*:.*\/\(.*\)$/\1/p')"

# Test database is postgresql database
test "$BAMBOO_DATABASE_TYPE" = "postgresql" || fail "Only postgresql database currently supported"

test -z "$BAMBOO_DATABASE_USERNAME" && fail "Failed to get database username for Bamboo from ${APPLICATION_DATA_DIR}/bamboo.cfg.xml"
test -z "$BAMBOO_DATABASE_PASSWORD" && fail "Failed to get database password for Bamboo from ${APPLICATION_DATA_DIR}/bamboo.cfg.xml"
test -z "$BAMBOO_DATABASE_SERVER" && fail "Failed to get database server address for Bamboo from ${APPLICATION_DATA_DIR}/bamboo.cfg.xml"
test -z "$BAMBOO_DATABASE_PORT" && fail "Failed to get database server port for Bamboo from ${APPLICATION_DATA_DIR}/bamboo.cfg.xml"
test -z "$BAMBOO_DATABASE_NAME" && fail "Failed to get database name for Bamboo from ${APPLICATION_DATA_DIR}/bamboo.cfg.xml"

if [ "$DEBUG" = "1" ]
then
    echo "Environment:"
    env
fi

# Backup
function backup_database() {
    filename=$1
    test -z "$filename" && fail "Dump filename cannot be empty"
    info "Backupping database ${BAMBOO_DATABASE_NAME} to ${BACKUP_DIR}/${filename}.gz"
    BACKUP_FILE="${BACKUP_DIR}/${filename}.gz"
    touch "${BACKUP_FILE}"
    chmod 600 "${BACKUP_FILE}"
    export PGPASSWORD="$BAMBOO_DATABASE_PASSWORD"
    export PGPORT="$BAMBOO_DATABASE_PORT"
    export PGHOST="$BAMBOO_DATABASE_SERVER"
    export PGUSER="$BAMBOO_DATABASE_USERNAME"
    pg_dump $BAMBOO_DATABASE_NAME |gzip -c > "${BACKUP_FILE}"
    chmod 600 "${BACKUP_FILE}"
}


function backup_bamboo() {
    test -f "${BAMBOO_PREVIOUS}/atlassian-bamboo/WEB-INF/classes/bamboo-init.properties" || fail "${BAMBOO_PREVIOUS}/atlassian-bamboo/WEB-INF/classes/bamboo-init.properties no such file"

    test -d "${BACKUP_DIR}" || ( mkdir "${BACKUP_DIR}"; chmod 700 "${BACKUP_DIR}" )

    backup_database "bamboo-${BAMBOO_VERSION}.sql"

    
    #test -d "${BINBACKUPDIR}" || ( mkdir "${BINBACKUPDIR}"; chmod 700 "${BINBACKUPDIR}" )
    test -d "${APPLICATION_DATA_BACKUP_DIR}" || ( mkdir "${APPLICATION_DATA_BACKUP_DIR}"; chmod 700 "${APPLICATION_DATA_BACKUP_DIR}" )

    # Skip for now
    #backup_files "${BAMBOO_PREVIOUS}" "${BINBACKUPDIR}"

    backup_files "${APPLICATION_DATA_DIR}" "${APPLICATION_DATA_BACKUP_DIR}"

}
