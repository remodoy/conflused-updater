#!/bin/bash

#
# Update Confluence to most recent version.
#

if [ -z "$1" ]
then
    echo "Usage $0 path/to/config.sh"
    exit 1
fi

export CONFIG_FILE="$1"

set -e

set -x
if [ "$DEBUG" = "1" ]
then
    # set -x when debug
    set -x
fi

export THIS=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Include commons
. ${THIS}/confluence_common.sh

# Include helpers
. ${THIS}/../helpers.sh

CONFLUENCE_TGZ="$(mktemp -u --suffix=.tar.gz)"

function post_cleanup() {
    rm $CONFLUENCE_TGZ || true
}

trap post_cleanup SIGINT SIGTERM

# Get newest version

CONFLUENCE_NEW_VERSION="$(latest_version confluence)"

set +e

vercomp "$CONFLUENCE_VERSION" "$CONFLUENCE_NEW_VERSION"
RES=$?
set -e

if [ $RES -lt 2 ]
then
    info "Current Confluence versio $CONFLUENCE_VERSION is up-to-date"
    exit 0 
fi

CONFLUENCE_NEW="${CONFLUENCE_BASE}/confluence-${CONFLUENCE_NEW_VERSION}"

CONFLUENCE_DOWNLOAD_URL="$(latest_version_url confluence)"

info "Downloading new Confluence"

wget -O "$CONFLUENCE_TGZ" "$CONFLUENCE_DOWNLOAD_URL"

# Do initial backup

backup_confluence

# Stop Confluence

if [ "${CONFLUENCE_SERVICE_NAME}" != "disable" ]
then
    servicemanager "${CONFLUENCE_SERVICE_NAME}" stop

    # wait for Confluence to stop
    sleep 60
fi


# Backup Confluence again

backup_confluence

#Unzip new Confluence

mkdir "$CONFLUENCE_NEW"

info "Unzipping new CONFLUENCE"
tar --strip-components=1 -xf "$CONFLUENCE_TGZ" -C "$CONFLUENCE_NEW"

# Remove tempdir
rm "$CONFLUENCE_TGZ"

# Restore some files from previous version

info "Restoring some config files"

restore_file "${CONFLUENCE_PROPERTIES_FILE}" "${CONFLUENCE_PREVIOUS}" "${CONFLUENCE_NEW}"

restore_file bin/setenv.sh "${CONFLUENCE_PREVIOUS}" "${CONFLUENCE_NEW}"

restore_file bin/user.sh "${CONFLUENCE_PREVIOUS}" "${CONFLUENCE_NEW}"

restore_file conf/server.xml "${CONFLUENCE_PREVIOUS}" "${CONFLUENCE_NEW}"

info "Setting permissions..."

chown -R "$CONFLUENCE_USER" "${CONFLUENCE_NEW}/temp"
chown -R "$CONFLUENCE_USER" "${CONFLUENCE_NEW}/logs"
chown -R "$CONFLUENCE_USER" "${CONFLUENCE_NEW}/work"

# TODO: version specific stuff here!!

set +e

vercomp "$CONFLUENCE_VERSION" "6.0.0"
RES1=$?
vercomp "$CONFLUENCE_NEW_VERSION" "6.0.0"
RES2=$?

if [ $RES1 -eq 2 ] && [ $RES2 -lt 2 ]
then
	info "Remember to add /synchrony config to your web server configuration"
	info "https://confluence.atlassian.com/confkb/how-to-use-nginx-to-proxy-requests-for-confluence-313459790.html"
	info "https://confluence.atlassian.com/doc/using-apache-with-mod_proxy-173669.html"
fi
set -e

# Update rest of things

info "Updating current symlink"
rm ${CONFLUENCE_CURRENT}
ln -s ${CONFLUENCE_NEW} ${CONFLUENCE_CURRENT}

info "Confluence is now updated!"

if [ "${CONFLUENCE_SERVICE_NAME}" != "disable" ]
then
    info "Starting Confluence"
    servicemanager "${CONFLUENCE_SERVICE_NAME}" start
    info "Be patient, Confluence is starting up"
fi
