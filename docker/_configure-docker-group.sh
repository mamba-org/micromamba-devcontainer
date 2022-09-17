#!/bin/bash

echo "Configuring Docker group..."

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
        sudo usermod -aG "${docker_gid}" "$(id -u -n)"
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
        sudo usermod -aG "${docker_group_name}" "$(id -u -n)"
    fi
  fi
fi
