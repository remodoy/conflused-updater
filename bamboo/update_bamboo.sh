#!/bin/bash

#
# Update Bamboo to most recent version.
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
. ${THIS}/bamboo_common.sh

# Include helpers
. ${THIS}/../helpers.sh

BAMBOO_TGZ="$(mktemp -u --suffix=.tar.gz)"

function post_cleanup() {
    rm $BAMBOO_TGZ || true
}

trap post_cleanup SIGINT SIGTERM

# Download newest

BAMBOO_NEW_VERSION="$(latest_version bamboo)"
BAMBOO_DOWNLOAD_URL="$(latest_version_url bamboo)"

set +e

vercomp "$BAMBOO_VERSION" "$BAMBOO_NEW_VERSION" '<='
RES=$?
set -e

if [ $RES -lt 2 ]
then
    info "Current Bamboo versio $BAMBOO_VERSION is up-to-date"
    exit 0 
fi

BAMBOO_NEW="${BAMBOO_BASE}/bamboo-${BAMBOO_NEW_VERSION}"

info "Downloading new Bamboo"

wget -O "$BAMBOO_TGZ" "$BAMBOO_DOWNLOAD_URL"

# Do initial backup

backup_bamboo

if [ "${BAMBOO_SERVICE_NAME}" != "disable" ]
then
    # Stop Bamboo
    servicemanager "${BAMBOO_SERVICE_NAME}" stop

    # wait for Bamboo to stop
    sleep 60
fi

# Backup Bamboo again

backup_bamboo

#Unzip new Bamboo

mkdir "$BAMBOO_NEW"

info "Unzipping new Bamboo"
tar --strip-components=1 -xf "$BAMBOO_TGZ" -C "$BAMBOO_NEW"

# Remove tempdir
rm "$BAMBOO_TGZ"

# Restore some files from previous version

info "Restoring some config files"

restore_file atlassian-bamboo/WEB-INF/classes/bamboo-init.properties "${BAMBOO_PREVIOUS}" "${BAMBOO_NEW}"
restore_file bin/setenv.sh "${BAMBOO_PREVIOUS}" "${BAMBOO_NEW}"
restore_file conf/server.xml "${BAMBOO_PREVIOUS}" "${BAMBOO_NEW}"

info "Setting permissions..."
chown -R "$BAMBOO_USER:$BAMBOO_USER" "${BAMBOO_NEW}"

info "Updating current symlink"
rm ${BAMBOO_CURRENT}
ln -s ${BAMBOO_NEW} ${BAMBOO_CURRENT}

info "Bamboo is now updated!"

if [ "${BAMBOO_SERVICE_NAME}" != "disable" ]
then
    info "Starting Bamboo"
    servicemanager "${BAMBOO_SERVICE_NAME}" start
    info "Be patient, Bamboo is starting up"
fi
