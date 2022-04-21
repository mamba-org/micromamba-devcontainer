# micromamba-devcontainer

A micromamba-based VS Code development container.

## Introduction

This repository hosts the base image for a VS Code development container which comes with:

* Basic command-line utilities
* Git, with some helpful defaults, e.g. [pre-commit](https://pre-commit.com)-ready
* Docker ("from Docker", i.e. connecting to a mounted `/var/run/docker.sock`), Docker Compose, BuildKit
* Micromamba

## Usage

See this [example](https://github.com/maresb/micromamba-devcontainer-example) and this [cookiecutter template](https://gitlab.com/bmares/cookiecutter-micromamba-devcontainer).

## Configuration

### SSH agent

VS Code can automatically forward your local SSH keys (e.g. for use with Git) to the development container (even when that development container is remote). Detailed instructions are [here](https://code.visualstudio.com/docs/remote/troubleshooting#_setting-up-the-ssh-agent).

The main steps are:

1. Make sure the SSH agent is running locally by opening a local terminal and listing your keys with `ssh-add -l`. (In case the agent is not running, follow the instructions in the above link.)
2. In case no keys are listed (`"The agent has no identities"`), add them by running `ssh-add`. (To instead add an individual key, run `ssh-add <path-to-key>`). Run `ssh-add -l` again to verify that the key was added.
3. Check if your keys are being forwarded to the container by opening an integrated terminal in the development container (`Ctrl`+`Shift`+``` ` ```) and running `ssh-add -l`. The results should agree with the local terminal.
