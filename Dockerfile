# To set up our environment, we start from Micromamba's base image. The latest tags
# can be found here: <https://hub.docker.com/r/mambaorg/micromamba/tags>
# For reproducibility, we should pin to a particular Git tag (not a micromamba version).

# For more info, about micromamba, see:
# <https://github.com/mamba-org/micromamba-docker>.

ARG BASE_IMAGE=mambaorg/micromamba:git-17cae43

# The folder to use as a workspace. The project should be mounted here.
ARG DEV_WORK_DIR=/work

FROM ${BASE_IMAGE}

# Grab gosu for switching users.
COPY --from=tianon/gosu /usr/local/bin/gosu /usr/local/bin/gosu

# Grab Docker, buildx, and Docker Compose
COPY --from=docker:dind /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker/buildx-bin /buildx /usr/libexec/docker/cli-plugins/docker-buildx
COPY --from=docker/compose /usr/local/bin/docker-compose /usr/local/bin/docker-compose

USER root

# Reallow installing manpages <https://unix.stackexchange.com/a/480460>
# (The Docker image is minified so manpages aren't included.)
RUN : \
    && sed -i '/path-exclude \/usr\/share\/man/d' /etc/dpkg/dpkg.cfg.d/docker \
    && sed -i '/path-exclude \/usr\/share\/groff/d' /etc/dpkg/dpkg.cfg.d/docker \
    ;

# Install some useful OS packages
RUN apt-get update && apt-get install -y --no-install-recommends --reinstall \
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
    libicu67 \
    #
    && rm -rf /var/lib/apt/lists/*


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

USER $MAMBA_USER

# Symlink the cache directories to the corresponding locations in home directory.
RUN : \
    && ln -s "/mnt/cache/vscode-server" "/home/${MAMBA_USER}/.vscode-server" \
    && mkdir -p "/home/${MAMBA_USER}/.cache" \
    && ln -s "/mnt/cache/pre-commit" "/home/${MAMBA_USER}/.cache/pre-commit" \
    ;

# Stack a development entrypoint after the default micromamba-docker entrypoint.
COPY dev-entrypoint.sh /usr/local/bin/_dev-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh", "/usr/local/bin/_dev-entrypoint.sh"]

# Prevent the container from shutting down
CMD echo "Sleeping forever." && sleep infinity
