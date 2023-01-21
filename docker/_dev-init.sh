#!/usr/bin/env bash

# Don't use strict mode so that we run through to the end. (commented out)
# set -euo pipefail

set -x

source _configure-docker-group.sh

# Fix ownership of cache directories
sudo chown "$(id -u):$(id -g)" \
    ~/.cache \
    ~/.cache/pre-commit \
;

# Set default blame ignore filename.
# This should only be done when it exists, due to <https://stackoverflow.com/q/70435937>
if [ -f .git-blame-ignore-revs ]; then
    git config --system blame.ignoreRevsFile .git-blame-ignore-revs
fi

# Make sure pre-commit is installed if .pre-commit-config exists
# (This is to take care of repositories which have already been cloned.
# Repositories cloned from within this devcontainer will acquire the
# pre-commit hook from /usr/share/git-core/templates/hooks/pre-commit.)
if [ -f .pre-commit-config.yaml ]; then
    if command -v pre-commit > /dev/null; then
        pre-commit install
    else
        echo '`pre-commit` is missing. Please install it in this dev container.' 1>&2
    fi
fi
