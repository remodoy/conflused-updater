#!/bin/bash

#
# Update JIRA to most recent version.
#

if [ -z "$1" ]
then
	echo "Usage $0 path/to/config.sh"
	exit 1
fi

export CONFIG_FILE="$1"

set -e

export THIS=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Include commons
. ${THIS}/jira_common.sh

# Include helpers
. ${THIS}/../helpers.sh

JIRA_TGZ="$(mktemp -u --suffix=.tar.gz)"

function post_cleanup() {
    rm $JIRA_TGZ || true
}

trap post_cleanup SIGINT SIGTERM

# Download newest

JIRA_NEW_VERSION="$(latest_version jira-core)"
 
set +e

vercomp "$JIRA_VERSION" '6.4' '<'
RES=$?
set -e

if [ $RES -gt 1 ]
then
    # 6.4 -> 7 update requires more attention
    JIRA_DOWNLOAD_URL="$(latest_version_url $JIRA_TYPE)"
else
    # Usually only jira-core update is required
    JIRA_DOWNLOAD_URL="$(latest_version_url jira-core)"
fi

set +e

vercomp "$JIRA_VERSION" "$JIRA_NEW_VERSION" '<='
RES=$?
set -e

if [ $RES -lt 2 ]
then
    info "Current JIRA versio $JIRA_VERSION is up-to-date"
    exit 0 
fi

JIRA_NEW="${JIRA_BASE}/jira-${JIRA_NEW_VERSION}"

info "Downloading new JIRA"

wget -O "$JIRA_TGZ" "$JIRA_DOWNLOAD_URL"

# Do initial backup

backup_jira

if [ "${JIRA_SERVICE_NAME}" != "disable" ]
then
    # Stop JIRA
    servicemanager "${JIRA_SERVICE_NAME}" stop

    # wait for JIRA to stop
    sleep 60
fi

# Backup JIRA again

backup_jira

#Unzip new JIRA

mkdir "$JIRA_NEW"

info "Unzipping new JIRA"
tar --strip-components=1 -xf "$JIRA_TGZ" -C "$JIRA_NEW"

# Remove tempdir
rm "$JIRA_TGZ"

# Restore some files from previous version

info "Restoring some config files"

restore_file atlassian-jira/WEB-INF/classes/jira-application.properties "${JIRA_PREVIOUS}" "${JIRA_NEW}"

restore_file bin/setenv.sh "${JIRA_PREVIOUS}" "${JIRA_NEW}"

restore_file bin/user.sh "${JIRA_PREVIOUS}" "${JIRA_NEW}"

restore_file conf/server.xml "${JIRA_PREVIOUS}" "${JIRA_NEW}"

info "Setting permissions..."

chown -R "$JIRA_USER" "${JIRA_NEW}/temp"
chown -R "$JIRA_USER" "${JIRA_NEW}/logs"
chown -R "$JIRA_USER" "${JIRA_NEW}/work"

# TODO: version specific stuff here!!

info "Updating current symlink"
rm ${JIRA_CURRENT}
ln -s ${JIRA_NEW} ${JIRA_CURRENT}

info "JIRA is now updated!"

if [ "${JIRA_SERVICE_NAME}" != "disable" ]
then
    info "Starting jira"
    servicemanager "${JIRA_SERVICE_NAME}" start
    info "Be patient, JIRA is starting up"
fi
