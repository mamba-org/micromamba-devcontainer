# micromamba-devcontainer

A micromamba-based VS Code development container.

## Introduction

This repository hosts the base image for a VS Code development container which comes with:

* Basic command-line utilities
* Git, with some helpful defaults, e.g. [pre-commit](https://pre-commit.com)-ready
* Docker ("from Docker", i.e. connecting to a mounted `/var/run/docker.sock`), Docker Compose, BuildKit
* Micromamba

## Usage

See this [example](https://github.com/maresb/micromamba-devcontainer-example).
