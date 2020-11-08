#!/bin/bash

#
# Update Bitbucket to most recent version.
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
. ${THIS}/bitbucket_common.sh

# Include helpers
. ${THIS}/../helpers.sh

BITBUCKET_TGZ="$(mktemp -u --suffix=.tar.gz)"

function post_cleanup() {
    rm $BITBUCKET_TGZ || true
}

trap post_cleanup SIGINT SIGTERM

# Download newest
BITBUCKET_NEW_VERSION="$(latest_version stash)"
BITBUCKET_DOWNLOAD_URL="$(latest_version_url stash)"

echo New $BITBUCKET_NEW_VERSION
echo Current $BITBUCKET_VERSION

set +e

vercomp "$BITBUCKET_VERSION" "$BITBUCKET_NEW_VERSION" '<='
RES=$?
set -eo pipefail

if [ $RES -lt 2 ]
then
    info "Current Bitbucket version $BITBUCKET_VERSION is up-to-date"
    exit 0 
fi

BITBUCKET_NEW="${BITBUCKET_BASE}/bitbucket-${BITBUCKET_NEW_VERSION}"

info "Downloading new Bitbucket"

wget -O "$BITBUCKET_TGZ" "$BITBUCKET_DOWNLOAD_URL"

# Do initial backup

backup_bitbucket

if [ "${BITBUCKET_SERVICE_NAME}" != "disable" ]
then
    # Stop Bitbucket
    servicemanager "${BITBUCKET_SERVICE_NAME}" stop

    # wait for Bitbucket to stop
    sleep 60
fi

# Backup Bitbucket again

backup_bitbucket

#Unzip new Bitbucket

mkdir "$BITBUCKET_NEW"

info "Unzipping new Bitbucket"
tar --strip-components=1 -xf "$BITBUCKET_TGZ" -C "$BITBUCKET_NEW"

# Remove tempdir
rm "$BITBUCKET_TGZ"

# Restore some files from previous version

info "Restoring some config files"

restore_file bin/set-jre-home.sh "${BITBUCKET_PREVIOUS}" "${BITBUCKET_NEW}"
restore_file bin/set-bitbucket-home.sh "${BITBUCKET_PREVIOUS}" "${BITBUCKET_NEW}"
restore_file bin/set-bitbucket-user.sh "${BITBUCKET_PREVIOUS}" "${BITBUCKET_NEW}"

info "Setting permissions..."
chown -R "${BITBUCKET_USER}:${BITBUCKET_USER}" "${BITBUCKET_NEW}"

# TODO: version specific stuff here!!

info "Updating current symlink"
rm ${BITBUCKET_CURRENT}
ln -s ${BITBUCKET_NEW} ${BITBUCKET_CURRENT}

info "Bitbucket is now updated!"

if [ "${BITBUCKET_SERVICE_NAME}" != "disable" ]
then
    info "Starting Bitbucket"
    servicemanager "${BITBUCKET_SERVICE_NAME}" start
    info "Be patient, Bitbucket is starting up"
fi
