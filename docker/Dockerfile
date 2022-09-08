# To set up our environment, we start from Micromamba's base image. The latest tags
# can be found here: <https://hub.docker.com/r/mambaorg/micromamba/tags>
# For reproducibility, we should pin to a particular Git tag (not a micromamba version).

# For more info, about micromamba, see:
# <https://github.com/mamba-org/micromamba-docker>.

ARG BASE_IMAGE=mambaorg/micromamba:git-70919b8-jammy

# The folder to use as a workspace. The project should be mounted here.
ARG DEV_WORK_DIR=/workspaces

FROM ${BASE_IMAGE}

# Grab gosu for switching users.
COPY --from=tianon/gosu /usr/local/bin/gosu /usr/local/bin/gosu

# Grab Docker and buildx
COPY --from=docker:dind /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker/buildx-bin /buildx /usr/libexec/docker/cli-plugins/docker-buildx

USER root

# Reallow installing manpages. (See Ubuntu's "unminimize" script.)
# (The Ubuntu image is minified so manpages aren't included.)
RUN rm \
        /etc/dpkg/dpkg.cfg.d/excludes \
        /etc/update-motd.d/60-unminimize \
        /usr/bin/man \
    && dpkg-divert --quiet --remove --rename /usr/bin/man

# Install some useful OS packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends --reinstall \
    # certs for https
    ca-certificates \
    #
    # manpages
    man-db \
    #
    # reinstall coreutils to get manpages for the standard commands (e.g. cp)
    coreutils \
    #
    # runs commands as superuser
    sudo \
    #
    # tab autocompletion for bash
    bash-completion \
    #
    # pagination
    less \
    #
    # monitor output of repeated command
    watch \
    #
    # version control
    git \
    patch \
    #
    # Git Large File Storage
    git-lfs \
    #
    # simple text editor
    nano \
    #
    # less-simple text editor
    vim \
    #
    # parses JSON on the bash command line
    jq \
    #
    # GNU Privacy Guard
    gnupg2 \
    #
    # ssh
    openssh-client \
    #
    # determines file types
    file \
    #
    # process monitor
    htop \
    #
    # compression
    zip \
    unzip \
    p7zip-full \
    #
    # downloads files
    curl \
    wget \
    #
    # lists open files
    lsof \
    #
    # ping and ip utilities
    iputils-ping \
    iproute2 \
    #
    # ifconfig, netstat, etc.
    net-tools \
    #
    # nslookup and dig (for looking up hostnames)
    dnsutils \
    #
    # socket cat for bidirectional byte streams
    socat \
    #
    # TCP terminal
    telnet \
    #
    # used by VS Code LiveShare extension
    libicu[0-9][0-9] \
    #
    && rm -rf /var/lib/apt/lists/*

# Old SSL library is needed for Live Share
# <https://github.com/MicrosoftDocs/live-share/issues/3297#issuecomment-1206805848>
RUN : \
  && wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb \
  && sudo dpkg -i ./libssl1.1_1.1.0g-2ubuntu4_amd64.deb \
  && rm libssl1.1_1.1.0g-2ubuntu4_amd64.deb \
;

RUN : \
    # Grant sudo to the user.
    && usermod -aG sudo "${MAMBA_USER}" \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/grant-to-sudo-group \
    ;

# Install docker-compose
RUN : \
    && COMPOSE_VERSION=$(git ls-remote https://github.com/docker/compose | grep refs/tags | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+$" | sort --version-sort | tail -n 1) \
    && sh -c "curl -L https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m) > /usr/local/bin/docker-compose" \
    && chmod +x /usr/local/bin/docker-compose \
    && COMPOSE_SWITCH_VERSION=$(git ls-remote https://github.com/docker/compose-switch | grep refs/tags | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+$" | sort --version-sort | tail -n 1) \
    && sh -c "curl -L https://github.com/docker/compose/releases/download/${COMPOSE_SWITCH_VERSION}/docker-compose-$(uname -s)-$(uname -m) > /usr/local/bin/compose-switch" \
    && chmod +x /usr/local/bin/compose-switch \
    ;

# Install bash completions
RUN : \
    && mkdir -p /etc/bash_completion.d \
    && sh -c "curl -L https://raw.githubusercontent.com/docker/compose/1.29.2/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose" \
    && sh -c "curl -L https://raw.githubusercontent.com/docker/cli/v20.10.13/contrib/completion/bash/docker > /etc/bash_completion.d/docker" \
    && sh -c "curl -L https://raw.githubusercontent.com/git/git/v2.35.1/contrib/completion/git-completion.bash > /etc/bash_completion.d/git" \
    ;

# Make sure we own the working directory.
ARG DEV_WORK_DIR
RUN : \
    && mkdir -p "${DEV_WORK_DIR}" \
    && chown "$MAMBA_USER:$MAMBA_USER" "${DEV_WORK_DIR}"

# Set the working directory.
ENV DEV_WORK_DIR="${DEV_WORK_DIR}"
WORKDIR "${DEV_WORK_DIR}"

# Sane defaults for Git
RUN : \
    # Switch default editor from vim to nano
    && git config --system core.editor nano \
    # Prevent unintentional merges
    # <https://blog.sffc.xyz/post/185195398930/why-you-should-use-git-pull-ff-only-git-is-a>
    && git config --system pull.ff only \
    # Use default branch name "main" instead of "master"
    && git config --system init.defaultBranch main \
    # Initialize Git LFS
    && git lfs install --system --skip-repo \
    ;
# Install Git pre-commit hook
COPY pre-commit-hook.sh /usr/share/git-core/templates/hooks/pre-commit
# Override any existing templateDir defined in ~/.gitconfig
#   <https://git-scm.com/docs/git-init#_template_directory>
ENV GIT_TEMPLATE_DIR=/usr/share/git-core/templates

# Create a user-accessible cache directory.
# For persistence, mount a volume or multiple volumes.
RUN mkdir -p "/mnt/cache" && chown "$MAMBA_USER:$MAMBA_USER" "/mnt/cache"

USER $MAMBA_USER

# Symlink the cache directories to the corresponding locations in home directory.
RUN : \
    && mkdir -p "/home/${MAMBA_USER}/.vscode-server" "/home/${MAMBA_USER}/.cache" \
        "/mnt/cache/vscode-server-extensions" "/mnt/cache/pre-commit" \
    && ln -s "/mnt/cache/vscode-server-extensions" "/home/${MAMBA_USER}/.vscode-server/extensions" \
    && ln -s "/mnt/cache/pre-commit" "/home/${MAMBA_USER}/.cache/pre-commit" \
    ;

# Set CMD script to run on container startup.
COPY _dev-cmd.sh /usr/local/bin/_dev-cmd.sh
COPY _configure-docker-group.sh /usr/local/bin/_configure-docker-group.sh
CMD _dev-cmd.sh
