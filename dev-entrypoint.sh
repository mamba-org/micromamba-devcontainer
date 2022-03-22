#!/usr/bin/env bash

# This script runs whenever the container starts before the CMD is executed.

# Don't use strict mode so that we run through to the end. (commented out)
# set -euo pipefail

set -x

# For some reason, VS Code doesn't display this output when starting the dev container.
# Log it to a file so that we can check it if needed.
# Redirect stdout ( > ) into a named pipe ( >() ) running "tee"
# <https://stackoverflow.com/a/3403786>

# Assign original stdout and stderr to file descriptors so that we can restore them later.
exec {stdout_alias}>&1 {stderr_alias}>&2

# Redirect stdout and stderr to a file.
exec 1> >(sudo tee -i /var/log/dev-entrypoint.log)
exec 2>&1


echo "Initialize the dev container..."

# Set the user and group
# <https://github.com/mamba-org/micromamba-docker#changing-the-user-id-or-name>
if [[ ! -z "${NEW_MAMBA_USER}" ]] && [[ "${MAMBA_USER}" != "${NEW_MAMBA_USER}" ]]; then
    NEW_MAMBA_USER_ID="$(stat --format=%u "${DEV_WORK_DIR}")"
    NEW_MAMBA_USER_GID="$(stat --format=%u "${DEV_WORK_DIR}")"
    sudo usermod "--login=${NEW_MAMBA_USER}" "--home=/home/${NEW_MAMBA_USER}" \
        --move-home "-u ${NEW_MAMBA_USER_ID}" "${MAMBA_USER}"
    sudo groupmod "--new-name=${NEW_MAMBA_USER}" "-g ${NEW_MAMBA_USER_GID}" "${MAMBA_USER}"
    # Update the expected value of MAMBA_USER for the _entrypoint.sh consistency check.
    echo "${NEW_MAMBA_USER}" | sudo tee "/etc/arg_mamba_user" > /dev/null
    export MAMBA_USER="${NEW_MAMBA_USER}"
fi

# Configure Docker permissions.
if [[ -S /var/run/docker.sock ]] ; then
  # Get the GID of the "docker" group.
  docker_gid=`stat --format=%g /var/run/docker.sock`
  if [ -z "$docker_gid" ] ; then
    echo "No mounted Docker socket found."
  else
    # Change GID of the "docker" group to match the mounted Docker socket.
    echo "Changing the GID of the 'docker' group to ${docker_gid}."
    sudo groupmod -g $docker_gid docker
  fi
fi

# Customize git.
if [[ ! -z "${GIT_NAME}" ]]; then
    sudo --user="${MAMBA_USER}" -- git config --global user.name "${GIT_NAME}"
else
    echo 'GIT_NAME is undefined.'
fi
if [[ ! -z "${GIT_EMAIL}" ]]; then
    sudo --user="${MAMBA_USER}" -- git config --global user.email "${GIT_EMAIL}"
else
    echo 'GIT_EMAIL is undefined.'
fi

# Restore the original stdout and stderr.
exec 2>&${stderr_alias} 1>&${stdout_alias}

# Pass execution to the CMD.
if [ ${#@} -gt 0 ]; then
    sudo --user "${MAMBA_USER}" "${@}"
else
    # The arguments list is empty, so default to Bash.
    sudo --user "${MAMBA_USER}" "/bin/bash"
fi
