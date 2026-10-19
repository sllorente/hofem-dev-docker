# syntax=docker/dockerfile:1
ARG TOOLCHAIN_IMAGE=hofem-dev:latest
FROM ubuntu:24.04 AS gnu-dev

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV MODULEPATH_ROOT=/opt/modulefiles \
    MODULEPATH=/opt/modulefiles/Core

# Ubuntu's parallel numerical libraries use GNU Fortran and OpenMPI.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential gfortran gdb cmake ninja-build pkg-config \
        autoconf automake libtool git curl ca-certificates gnupg unzip \
        python3 lmod openmpi-bin libopenmpi-dev \
        libopenblas-openmp-dev liblapack-dev libscalapack-openmpi-dev \
        libmetis-dev libparmetis-dev libscotch-dev libptscotch-dev \
        libarpack2-dev libparpack2-dev libmumps-dev \
        zlib1g-dev libhdf5-dev \
    && rm -rf /var/lib/apt/lists/*

COPY modulefiles/ /usr/local/share/hofem/modulefiles/
COPY docker/configure-modules.py /usr/local/sbin/hofem-configure-modules
RUN python3 /usr/local/sbin/hofem-configure-modules gnu
COPY docker/entrypoint.sh /usr/local/bin/hofem-entrypoint
COPY tests/toolchains.sh /usr/local/bin/grema-smoke-test
RUN chmod 755 /usr/local/bin/hofem-entrypoint /usr/local/bin/grema-smoke-test \
    && useradd --create-home --uid 10001 --shell /bin/bash developer \
    && mkdir -p /workspace \
    && chown developer:developer /workspace \
    && printf '\nsource /etc/profile.d/lmod.sh\n' >> /etc/bash.bashrc

WORKDIR /workspace
USER developer
ENTRYPOINT ["/usr/local/bin/hofem-entrypoint"]
CMD ["/bin/bash"]

# Migration target: reuse installed compilers when rebuilding their layers is costly.
# Pin TOOLCHAIN_IMAGE to an existing image ID when building this target.
FROM ${TOOLCHAIN_IMAGE} AS reuse-toolchains
USER root
COPY modulefiles/ /usr/local/share/hofem/modulefiles/
COPY docker/configure-modules.py /usr/local/sbin/hofem-configure-modules
COPY docker/install-intel.sh /usr/local/sbin/hofem-install-intel
COPY docker/prepare-base.sh /usr/local/sbin/grema-prepare-base
COPY tests/toolchains.sh /usr/local/bin/grema-smoke-test
RUN bash /usr/local/sbin/grema-prepare-base \
    && chmod 755 /usr/local/bin/grema-smoke-test
LABEL org.opencontainers.image.title="grema-dev"
USER developer

FROM gnu-dev AS intel-base
USER root

# Intel oneAPI Linux compilers require x86-64. GNU-only builds can use gnu-dev.
RUN test "$(dpkg --print-architecture)" = amd64 \
    && curl -fsSL --retry 3 \
        https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
        | gpg --dearmor -o /usr/share/keyrings/oneapi-archive-keyring.gpg
RUN printf '%s\n' \
        'deb [arch=amd64 signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main' \
        > /etc/apt/sources.list.d/oneapi.list
COPY docker/install-intel.sh /usr/local/sbin/hofem-install-intel

FROM intel-base AS intel-2025
# Install the newest patches within the requested release series.
RUN bash /usr/local/sbin/hofem-install-intel 2025.3 2025.3 2021.17 2025.3

USER developer

FROM intel-2025 AS development
LABEL org.opencontainers.image.title="grema-dev"
USER root
# Resolve current release series from APT metadata, then install payload packages.
RUN bash /usr/local/sbin/hofem-install-intel latest \
    && touch /usr/local/share/hofem/three-stacks

USER developer
