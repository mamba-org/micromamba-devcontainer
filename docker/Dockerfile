# To set up our environment, we start from Micromamba's base image. The latest tags
# can be found here: <https://hub.docker.com/r/mambaorg/micromamba/tags>
# For reproducibility, we should pin to a particular Git tag (not a micromamba version).

# For more info, about micromamba, see:
# <https://github.com/mamba-org/micromamba-docker>.

ARG BASE_IMAGE=mambaorg/micromamba:git-9051915-jammy@sha256:0fb5693cd4aaa841e63e618506b58ca58a1549116ee8fe00047d1d6af04dd8d8

# The folder to use as a workspace. The project should be mounted here.
ARG DEV_WORK_DIR=/workspaces

FROM ${BASE_IMAGE}

# Grab gosu for switching users.
COPY --from=tianon/gosu /usr/local/bin/gosu /usr/local/bin/gosu

USER root

ENV USERNAME=mambauser
COPY vendored/library-scripts/common-debian-patched.sh /tmp/
RUN bash /tmp/common-debian-patched.sh && rm /tmp/common-debian-patched.sh

# Install some useful OS packages
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends --reinstall \
    # more helpful utils like sponge
    moreutils \
    #
    # tab autocompletion for bash
    bash-completion \
    #
    # monitor output of repeated command
    watch \
    #
    # version control
    patch \
    #
    # Git Large File Storage
    git-lfs \
    #
    # determines file types
    file \
    #
    # compression
    p7zip-full \
    #
    # ping and ip utilities
    iputils-ping \
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
    && rm -rf /var/lib/apt/lists/*

COPY vendored/features/docker-in-docker/install.sh /tmp/install.sh
RUN DOCKERDASHCOMPOSEVERSION=v2 bash /tmp/install.sh && rm /tmp/install.sh

# Make sure everyone can access the working directory.
ARG DEV_WORK_DIR
RUN : \
    && mkdir --parents --mode=777 "${DEV_WORK_DIR}" \
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

# Create pre-commit cache directory
RUN mkdir -p /home/$MAMBA_USER/.cache/pre-commit \
    && chown -R $MAMBA_USER:$MAMBA_USER \
        /home/$MAMBA_USER/.cache/pre-commit \
    # Additionally, make sure these directories are writable by everyone
    && chmod a+rwx \
        /home/$MAMBA_USER/.cache \
        /home/$MAMBA_USER/.cache/pre-commit \
;

# Set CMD script to run on container startup.
COPY _dev-init.sh /usr/local/bin/_dev-init.sh
COPY _configure-docker-group.sh /usr/local/bin/_configure-docker-group.sh
CMD [ \
    "bash", \
    "-c", \
    "_dev-init.sh; echo 'Sleeping forever.'; while sleep 1000; do :; done" \
]
