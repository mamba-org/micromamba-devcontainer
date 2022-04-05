#!/usr/bin/env bash

# This script runs whenever the container starts before the CMD is executed.

# Don't use strict mode so that we run through to the end. (commented out)
# set -euo pipefail

set -x

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
    if getent group "${docker_gid}" ; then
        # The group for the Docker socket's gid already exists.
        echo "Adding user to '$(getent group "${docker_gid}" | cut -d: -f1)' group for docker access."
        sudo usermod -aG "${docker_gid}" "${MAMBA_USER}"
    else
        # The group for the Docker socket's gid doesn't exist.
        if getent group docker ; then
          # The "docker" group exists, but doesn't match the gid of the Docker socket.
          docker_group_name="docker-conflicting-groupname"
        else
          docker_group_name="docker"
        fi
        echo "Setting the GID of the '${docker_group_name}' group to ${docker_gid}."
        sudo groupadd --force --gid "${docker_gid}" "${docker_group_name}"
        sudo usermod -aG "${docker_group_name}" "${MAMBA_USER}"
    fi
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

# Run pre-commit install if applicable.
if [ -f .pre-commit-config.yaml ]; then
    pre-commit install
fi

# Pass execution to the CMD.
if [ ${#@} -gt 0 ]; then
    sudo --user "${MAMBA_USER}" "${@}"
else
    # The arguments list is empty, so default to Bash.
    sudo --user "${MAMBA_USER}" "/bin/bash"
fi
