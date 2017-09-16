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

test -z "$BITBUCKET_PATH" && fail "BITBUCKET_PATH not set"
test -e "$BITBUCKET_PATH" || fail "Directory $BITBUCKET_PATH does not exist"
export BITBUCKET_BASE="$(realpath $BITBUCKET_PATH)"
test -z "$BITBUCKET_USER" && fail "BITBUCKET_USER not set"
test -z "$BITBUCKET_TYPE" && export BITBUCKET_TYPE="bitbucket"
test -z "$BITBUCKET_SERVICE_NAME" && export BITBUCKET_SERVICE_NAME="bitbucket"
test -d "$BITBUCKET_BASE" || fail "${BITBUCKET_BASE} is not a directory"


export BITBUCKET_BASE
export BITBUCKET_USER
export BITBUCKET_TYPE


export BITBUCKET_CURRENT="${BITBUCKET_BASE}/current"

test -h ${BITBUCKET_CURRENT} || fail "${BITBUCKET_CURRENT} is not a symbolic link"

# Previous bitbucket directory
readlink "${BITBUCKET_CURRENT}" > /dev/null 2>&1 || fail "${BITBUCKET_CURRENT} is a broken link"
export BITBUCKET_PREVIOUS="$(readlink -f ${BITBUCKET_CURRENT})"

# Get bitbucket version
export BITBUCKET_VERSION=$(get_init_value ${BITBUCKET_PREVIOUS}/atlassian-bitbucket/WEB-INF/classes/build.properties build.version)
test -z "$BITBUCKET_VERSION" && fail "Failed to fetch Bitbucket version from ${BITBUCKET_PREVIOUS}/atlassian-bitbucket/WEB-INF/classes/build.properties"

export BACKUP_DIR="${BACKUP_DIR:-${BITBUCKET_BASE}/backup}"

export BIN_BACKUP_DIR="${BACKUP_DIR}/binary"

export APPLICATION_DATA_BACKUP_DIR="${BACKUP_DIR}/application-data"

export APPLICATION_DATA_DIR="$(cat ${BITBUCKET_PREVIOUS}/bin/setenv.sh | sed -ne 's/.*export BITBUCKET_HOME=\(.*\)/\1/p')"

# Get database variables, bash </3 XML
export BITBUCKET_DATABASE_USERNAME="$(get_init_value ${APPLICATION_DATA_DIR}/shared/bitbucket.properties jdbc.user)"
export BITBUCKET_DATABASE_PASSWORD="$(get_init_value ${APPLICATION_DATA_DIR}/shared/bitbucket.properties jdbc.password)"
export BITBUCKET_DATABASE_URI="$(get_init_value ${APPLICATION_DATA_DIR}/shared/bitbucket.properties jdbc.url)"
export BITBUCKET_DATABASE_TYPE="$(echo $BITBUCKET_DATABASE_URI |sed  -ne 's/^jdbc:\([a-z][a-z]*\):\/\/.*/\1/p')"
export BITBUCKET_DATABASE_SERVER="$(echo $BITBUCKET_DATABASE_URI |sed  -ne 's/.*:\/\/\(.*\):.*/\1/p')"
export BITBUCKET_DATABASE_PORT="$(echo $BITBUCKET_DATABASE_URI |sed  -ne 's/.*:\/\/.*:\(.*\)\/.*/\1/p')"
export BITBUCKET_DATABASE_NAME="$(echo $BITBUCKET_DATABASE_URI |sed  -ne 's/.*:\/\/.*:.*\/\(.*\)$/\1/p')"

# Test database is postgresql database
test "$BITBUCKET_DATABASE_TYPE" = "postgresql" || fail "Only postgresql database currently supported"

test -z "$BITBUCKET_DATABASE_USERNAME" && fail "Failed to get database username for Bitbucket from ${APPLICATION_DATA_DIR}/shared/bitbucket.properties"
test -z "$BITBUCKET_DATABASE_PASSWORD" && fail "Failed to get database password for Bitbucket from ${APPLICATION_DATA_DIR}/shared/bitbucket.properties"
test -z "$BITBUCKET_DATABASE_SERVER" && fail "Failed to get database server address for Bitbucket from ${APPLICATION_DATA_DIR}/shared/bitbucket.properties"
test -z "$BITBUCKET_DATABASE_PORT" && fail "Failed to get database server port for Bitbucket from ${APPLICATION_DATA_DIR}/shared/bitbucket.properties"
test -z "$BITBUCKET_DATABASE_NAME" && fail "Failed to get database name for Bitbucket from ${APPLICATION_DATA_DIR}/shared/bitbucket.properties"

if [ "$DEBUG" = "1" ]
then
    echo "Environment:"
    env
fi

# Backup
function backup_database() {
    filename=$1
    test -z "$filename" && fail "Dump filename cannot be empty"
    info "Backupping database ${BITBUCKET_DATABASE_NAME} to ${BACKUP_DIR}/${filename}.gz"
    BACKUP_FILE="${BACKUP_DIR}/${filename}.gz"
    touch "${BACKUP_FILE}"
    chmod 600 "${BACKUP_FILE}"
    export PGPASSWORD="$BITBUCKET_DATABASE_PASSWORD"
    export PGPORT="$BITBUCKET_DATABASE_PORT"
    export PGHOST="$BITBUCKET_DATABASE_SERVER"
    export PGUSER="$BITBUCKET_DATABASE_USERNAME"
    pg_dump $BITBUCKET_DATABASE_NAME |gzip -c > "${BACKUP_FILE}"
    chmod 600 "${BACKUP_FILE}"
}


function backup_bitbucket() {
    test -d "${BACKUP_DIR}" || ( mkdir "${BACKUP_DIR}"; chmod 700 "${BACKUP_DIR}" )

    backup_database "bitbucket-${BITBUCKET_VERSION}.sql"

    
    #test -d "${BINBACKUPDIR}" || ( mkdir "${BINBACKUPDIR}"; chmod 700 "${BINBACKUPDIR}" )
    test -d "${APPLICATION_DATA_BACKUP_DIR}" || ( mkdir "${APPLICATION_DATA_BACKUP_DIR}"; chmod 700 "${APPLICATION_DATA_BACKUP_DIR}" )

    # Skip for now
    #backup_files "${BITBUCKET_PREVIOUS}" "${BINBACKUPDIR}"

    backup_files "${APPLICATION_DATA_DIR}" "${APPLICATION_DATA_BACKUP_DIR}"

}
