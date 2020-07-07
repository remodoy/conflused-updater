#@IgnoreInspection BashAddShebang
THIS=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Include helpers

. ${THIS}/../helpers.sh

. $CONFIG_FILE

# Handle user defined parameters

which realpath > /dev/null || fail "realpath not installed"

test_variable CONFLUENCE_BASE
test_variable CONFLUENCE_USER

test ! -z "$CONFLUENCE_SERVICE_NAME" || export CONFLUENCE_SERVICE_NAME="confluence"

test -d "${CONFLUENCE_BASE}" || fail "CONFLUENCE_BASE is not a directory"

export CONFLUENCE_BASE="$(realpath ${CONFLUENCE_BASE})"

export BACKUPDIR="${BACKUPDIR:-${CONFLUENCE_BASE}/backup}"

test ! -z "$BACKUPDIR" || fail "BACKUPDIR cannot be empty string"

export DEBUG="${DEBUG:-0}"

test -d "$CONFLUENCE_BASE" || fail "${CONFLUENCE_BASE} is not a directory"

# Fetch some variables from confluence configurations

export CONFLUENCE_CURRENT="${CONFLUENCE_BASE}/current"

test -h ${CONFLUENCE_CURRENT} || fail "${CONFLUENCE_CURRENT} is not link"

# Previous confluence directory
readlink "${CONFLUENCE_CURRENT}" > /dev/null 2>&1 || fail "${CONFLUENCE_CURRENT} is a broken link"
export CONFLUENCE_PREVIOUS="$(readlink -f ${CONFLUENCE_CURRENT})"

# Get confluence version
export CONFLUENCE_VERSION="$(get_init_value ${CONFLUENCE_PREVIOUS}/confluence/META-INF/maven/com.atlassian.confluence/confluence-webapp/pom.properties 'version')"

test -z "$CONFLUENCE_VERSION" && fail "Failed to fetch confluence version from ${CONFLUENCE_PREVIOUS}/confluence/META-INF/maven/com.atlassian.confluence/confluence-webapp/pom.properties"

export APPLICATIONDATABACKUPDIR="${BACKUPDIR}/application-data"

export CONFLUENCE_PROPERTIES_FILE="confluence/WEB-INF/classes/confluence-init.properties"

export APPLICATION_DATA_DIR="$(get_init_value ${CONFLUENCE_PREVIOUS}/${CONFLUENCE_PROPERTIES_FILE} confluence.home)"

test ! -z "$APPLICATION_DATA_DIR" || fail "Failed to find application-data directory"

# Get database variables, bash </3 XML
export CONFLUENCE_DATABASE_USERNAME="$(cat ${APPLICATION_DATA_DIR}/confluence.cfg.xml | sed -ne 's/.*<property name="hibernate.connection.username">\(.*\)<\/property>.*/\1/p')"
export CONFLUENCE_DATABASE_PASSWORD="$(cat ${APPLICATION_DATA_DIR}/confluence.cfg.xml | sed -ne 's/.*<property name="hibernate.connection.password">\(.*\)<\/property>.*/\1/p')"
export CONFLUENCE_DATABASE_URI="$(cat ${APPLICATION_DATA_DIR}/confluence.cfg.xml | sed -ne 's/.*<property name="hibernate.connection.url">\(.*\)<\/property>.*/\1/p')"
export CONFLUENCE_DATABASE_TYPE="$(echo $CONFLUENCE_DATABASE_URI |sed  -ne 's/^jdbc:\([a-z][a-z]*\):\/\/.*/\1/p')"
export CONFLUENCE_DATABASE_SERVER="$(echo $CONFLUENCE_DATABASE_URI |sed  -ne 's/.*:\/\/\(.*\):.*/\1/p')"
export CONFLUENCE_DATABASE_PORT="$(echo $CONFLUENCE_DATABASE_URI |sed  -ne 's/.*:\/\/.*:\(.*\)\/.*/\1/p')"
export CONFLUENCE_DATABASE_NAME="$(echo $CONFLUENCE_DATABASE_URI |sed  -ne 's/.*:\/\/.*:.*\/\([a-zA-Z0-9_-]*\)\(\?.*\)*$/\1/p')"

# Test database is postgresql database
test "$CONFLUENCE_DATABASE_TYPE" = "postgresql" || fail "Only postgresql database currently supported"


test ! -z "$CONFLUENCE_DATABASE_USERNAME" || fail "Failed to get database username for Confluence from ${APPLICATION_DATA_DIR}/confluence.cfg.xml"
test ! -z "$CONFLUENCE_DATABASE_PASSWORD" || fail "Failed to get database password for Confluence from ${APPLICATION_DATA_DIR}/confluence.cfg.xml"
test ! -z "$CONFLUENCE_DATABASE_SERVER" || fail "Failed to get database server address for Confluence from ${APPLICATION_DATA_DIR}/confluence.cfg.xml"
test ! -z "$CONFLUENCE_DATABASE_PORT" || fail "Failed to get database server port for Confluence from ${APPLICATION_DATA_DIR}/confluence.cfg.xml"
test ! -z "$CONFLUENCE_DATABASE_NAME" || fail "Failed to get database name for Confluence from ${APPLICATION_DATA_DIR}/confluence.cfg.xml"


# Backup
function backup_database() {
    filename=$1
    test -z "$filename" && fail "Dump filename cannot be empty"
    info "Backupping database ${CONFLUENCE_DATABASE_NAME} to ${BACKUPDIR}/${filename}.gz"
    local BACKUP_FILE="${BACKUPDIR}/${filename}.gz"
    touch "${BACKUP_FILE}"
    chmod 600 "${BACKUP_FILE}"
    PGPASSWORD="$CONFLUENCE_DATABASE_PASSWORD" \
    PGPORT="$CONFLUENCE_DATABASE_PORT" \
    PGHOST="$CONFLUENCE_DATABASE_SERVER" \
    PGUSER="$CONFLUENCE_DATABASE_USERNAME" \
    pg_dump $CONFLUENCE_DATABASE_NAME |gzip -c > "${BACKUP_FILE}" || fail "Failed to backup database"
    chmod 600 "${BACKUP_FILE}"
}


function backup_confluence() {
    test -f "${CONFLUENCE_PREVIOUS}/${CONFLUENCE_PROPERTIES_FILE}" || fail "${CONFLUENCE_PREVIOUS}/${CONFLUENCE_PROPERTIES_FILE} not such file"

    test -d "${BACKUPDIR}" || ( mkdir "${BACKUPDIR}"; chmod 700 "${BACKUPDIR}" )

    backup_database "confluence-${CONFLUENCE_VERSION}.sql"

    test -d "${APPLICATIONDATABACKUPDIR}" || ( mkdir "${APPLICATIONDATABACKUPDIR}"; chmod 700 "${APPLICATIONDATABACKUPDIR}" )

    backup_files "${APPLICATION_DATA_DIR}" "${APPLICATIONDATABACKUPDIR}"

}
