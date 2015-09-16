THIS=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Include helpers

. ${THIS}/../helpers.sh

export JIRA_DATABASE=jira
export ATLASSIAN_BASE=/opt/jira

export JIRA_BASE="$(realpath ${ATLASSIAN_BASE}/jira)/"

export JIRA_BANNER="$(find "$JIRA_BASE" -name jirabanner.txt)"

test -z $JIRA_BANNER && fail "Cannot get JIRA version"

export JIRA_VERSION=$(cat ${JIRA_BANNER} |sed -n -e 's/.*Version.*: \([0-9\.]*\)\r/\1/p')

export BACKUPDIR="$(realpath ${ATLASSIAN_BASE}/backup)"
export BINBACKUPDIR="$(realpath ${BACKUPDIR}/binary)"
export APPLICATIONDATABACKUPDIR="$(realpath ${BACKUPDIR}/application-data)"


export APPLICATION_DATA_DIR="$(cat ${JIRA_BASE}/atlassian-jira/WEB-INF/classes/jira-application.properties |awk -F '= ' '$1 ~ /jira.home.*/  { print $2 }')"


# Backup
function backup_database() {
    database=$1
    filename=$2
    test -z "$database" && fail "Database name cannot be empty"
    test -z "$filename" && fail "Dump filename cannot be empty"
    info "Backupping database to ${ATLASSIAN_BASE}/${filename}.gz"
    BACKUP_FILE="${BACKUPDIR}/${filename}.gz"
    touch "${BACKUP_FILE}"
    chown postgres "${BACKUP_FILE}"
    su - postgres -s /bin/bash -c "pg_dump $database |gzip -c > ${BACKUP_FILE}"
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
    test -f "${JIRA_BASE}/atlassian-jira/WEB-INF/classes/jira-application.properties" || fail "${JIRA_BASE}/atlassian-jira/WEB-INF/classes/jira-application.properties not such file"

    backup_database jira "jira-${JIRA_VERSION}.sql"

    test -d "${BACKUPDIR}" || mkdir "${BACKUPDIR}"
    test -d "${BINBACKUPDIR}" || mkdir "${BINBACKUPDIR}"
    test -d "${APPLICATIONDATABACKUPDIR}" || mkdir "${APPLICATIONDATABACKUPDIR}"

    backup_files "${JIRA_BASE}" "${BINBACKUPDIR}"


    backup_files "${APPLICATION_DATA_DIR}" "${APPLICATIONDATABACKUPDIR}"

}
