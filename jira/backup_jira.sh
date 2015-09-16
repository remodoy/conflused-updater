#!/bin/bash

set -e
set -x

export THIS=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

# Include commons
. ${THIS}/jira_common

# Include helpers
. ${THIS}/../helpers.sh

# Do backup

backup_jira