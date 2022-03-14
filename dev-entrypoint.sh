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

# Make sure the mounted volume is fully accessible to all users.
if [[ -d /mnt/.vscode-server ]]; then
  sudo chmod a+rwx /mnt/.vscode-server
fi

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

# Set up the Docker if mounted.
if [[ -S /var/run/docker.sock ]] ; then
  # Get the GID of the "docker" group.
  docker_gid=`stat --format=%g /var/run/docker.sock`
  if [ -z "$docker_gid" ] ; then
    echo "No mounted Docker socket found."
  else
    # Create docker group if it doesn't already exist.
    [ $(getent group docker) ] || sudo groupadd docker

    # Try to create a new group with this GID. This will fail if the
    # GID is already assigned.
    sudo groupmod -g $docker_gid docker

    # Add user to the "docker" group.
    sudo usermod -a -G docker "${MAMBA_USER}"
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
if [[ -x "${MAMBA_ROOT_PREFIX}"/bin/pre-commit ]]; then
    # pre-commit is installed, so configure it to always run.
    # <https://pre-commit.com/#automatically-enabling-pre-commit-on-repositories>

    # Get home of user from username <https://stackoverflow.com/a/53564881>
    mamba_home="$(getent passwd "$MAMBA_USER" | cut -d: -f6)"

    template_dir="${mamba_home}/.git-template"
    sudo --user="${MAMBA_USER}" -- git config --global \
        init.templateDir "${template_dir}"
    sudo --user="${MAMBA_USER}" -- "${MAMBA_ROOT_PREFIX}"/bin/pre-commit \
        init-templatedir "${template_dir}"
else
    echo "pre-commit not found, skipping pre-commit init"
fi

# Restore the original stdout and stderr.
exec 2>&${stderr_alias} 1>&${stdout_alias}

# Pass execution to the CMD.
if [ ${#@} -gt 0 ]; then
    exec "${@}"
else
    # The arguments list is empty, so default to Bash.
    exec "/bin/bash"
fi
