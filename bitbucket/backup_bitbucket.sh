#!/bin/bash

set -e
set -x

export THIS=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

if [ -z "$1" ]
then
    echo "Usage $0 path/to/config.sh"
    exit 1
fi

export CONFIG_FILE="$1"

# Include commons
. ${THIS}/bitbucket_common

# Include helpers
. ${THIS}/../helpers.sh

# Do backup

backup_bitbucket
