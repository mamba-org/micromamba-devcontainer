#!/usr/bin/env bash

# Run pre-commit if available, raise error if it's missing and necessary. Original:
#  <https://github.com/pre-commit/pre-commit/blob/master/pre_commit/resources/hook-tmpl>

ARGS=(hook-impl --config=.pre-commit-config.yaml --hook-type=pre-commit --skip-on-missing-config)

HERE="$(cd "$(dirname "$0")" && pwd)"
ARGS+=(--hook-dir "$HERE" -- "$@")

if command -v pre-commit > /dev/null; then
    exec pre-commit "${ARGS[@]}"
else
    # We are in the repository root. <https://stackoverflow.com/a/37927943>
    if [[ -f .pre-commit-config.yaml ]]; then
        echo '`pre-commit` is missing. Please install it in this dev container.' 1>&2
        exit 1
    fi
    # neither `pre-commit` nor `.pre-commit-config.yaml` found, so exit silently.
fi
