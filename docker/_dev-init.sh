#!/usr/bin/env bash

# Don't use strict mode so that we run through to the end. (commented out)
# set -euo pipefail

set -x

source _configure-docker-group.sh

# Set default blame ignore filename.
# This should only be done when it exists, due to <https://stackoverflow.com/q/70435937>
if [ -f .git-blame-ignore-revs ]; then
    git config --system blame.ignoreRevsFile .git-blame-ignore-revs
fi
