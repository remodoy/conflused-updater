#!/bin/bash

#
# Update CROWD to most recent version.
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
. ${THIS}/crowd_common.sh

# Include helpers
. ${THIS}/../helpers.sh

CROWD_TGZ="$(mktemp -u --suffix=.tar.gz)"

function post_cleanup() {
    rm $CROWD_TGZ || true
}

trap post_cleanup SIGINT SIGTERM

# Download newest

CROWD_NEW_VERSION="$(latest_version crowd)"
 
CROWD_DOWNLOAD_URL="$(latest_version_url crowd)"

set +e

vercomp "$CROWD_VERSION" "$CROWD_NEW_VERSION" '<='
RES=$?
set -e

if [ $RES -lt 2 ]
then
    info "Current CROWD versio $CROWD_VERSION is up-to-date"
    exit 0 
fi

CROWD_NEW="${CROWD_BASE}/crowd-${CROWD_NEW_VERSION}"

info "Downloading new CROWD"

wget -O "$CROWD_TGZ" "$CROWD_DOWNLOAD_URL"

# Do initial backup

backup_crowd

if [ "${CROWD_SERVICE_NAME}" != "disable" ]
then
    # Stop CROWD
    servicemanager "${CROWD_SERVICE_NAME}" stop

    # wait for CROWD to stop
    sleep 60
fi

# Backup CROWD again

backup_crowd

#Unzip new CROWD

mkdir "$CROWD_NEW"

info "Unzipping new CROWD"
tar --strip-components=1 -xf "$CROWD_TGZ" -C "$CROWD_NEW"

# Remove tempdir
rm "$CROWD_TGZ"

# Restore some files from previous version

info "Restoring some config files"

restore_file crowd-webapp/WEB-INF/classes/crowd-init.properties "${CROWD_PREVIOUS}" "${CROWD_NEW}"

restore_file apache-tomcat/bin/setenv.sh "${CROWD_PREVIOUS}" "${CROWD_NEW}"

restore_file apache-tomcat/conf/server.xml "${CROWD_PREVIOUS}" "${CROWD_NEW}"

info "Setting permissions..."

chown -R "$CROWD_USER" "${CROWD_NEW}/apache-tomcat/temp"
chown -R "$CROWD_USER" "${CROWD_NEW}/apache-tomcat/logs"
chown -R "$CROWD_USER" "${CROWD_NEW}/apache-tomcat/work"

# TODO: version specific stuff here!!

info "Updating current symlink"
rm ${CROWD_CURRENT}
ln -s ${CROWD_NEW} ${CROWD_CURRENT}

info "CROWD is now updated!"

if [ "${CROWD_SERVICE_NAME}" != "disable" ]
then
    info "Starting CROWD"
    servicemanager "${CROWD_SERVICE_NAME}" start
    info "Be patient, CROWD is starting up"
fi
