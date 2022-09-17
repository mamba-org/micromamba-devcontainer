#!/bin/bash

# Bash strict mode
set -euo pipefail

# The purpose of this script is to symlink the user's cache directories to
# /mnt/cache, which can optionally be mounted as a named volume.

# The user could be the default ${MAMBA_USER}, or root, or some new user. We
# cover each of these cases in the for loop.

mkdir --parents --mode=777 "/mnt/cache/vscode-server-extensions" "/mnt/cache/pre-commit"

for homedir in "/home/${MAMBA_USER}" "/root" "/etc/skel"; do
    mkdir --parents --mode=777 "${homedir}/.vscode-server" "${homedir}/.cache"
    ln --symbolic "/mnt/cache/vscode-server-extensions" "${homedir}/.vscode-server/extensions"
    ln --symbolic "/mnt/cache/pre-commit" "${homedir}/.cache/pre-commit"
done
