#!/bin/bash

# TODO: Download new jira

set -e
set -x

export THIS=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Include commons
. ${THIS}/jira_common.sh

# Include helpers
. ${THIS}/../helpers.sh

export JIRA_TGZ="$1"

test -z $JIRA_TGZ && fail "Usage: $0 new-jira.tar.gz"

# Do initial backup

backup_jira

servicemanager jira stop

# wait for jira to stop

# Backup jira again

backup_jira

#Unzip new jira

rm -r "$JIRA_BASE"

mkdir "$JIRA_BASE"

tar --strip-components=1 -xf "$JIRA_TGZ" -C "$JIRA_BASE"

# Restore some files from backup

info "Restoring some config files"

restore_file atlassian-jira/WEB-INF/classes/jira-application.properties "${BINBACKUPDIR}/jira" "${JIRA_BASE}"

restore_file bin/setenv.sh "${BINBACKUPDIR}/jira" "${JIRA_BASE}"

restore_file bin/user.sh "${BINBACKUPDIR}/jira" "${JIRA_BASE}"

restore_file conf/server.xml "${BINBACKUPDIR}/jira" "${JIRA_BASE}"

info "Setting permissions"

chown -R jira ${JIRA_BASE}/temp
chown -R jira ${JIRA_BASE}/logs
chown -R jira ${JIRA_BASE}/work


# TODO: version specific stuff here!!

info "Starting jira"

servicemanager jira start

echo "Jira updated, be patient jira is starting up"
