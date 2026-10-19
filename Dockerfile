# syntax=docker/dockerfile:1
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

ARG GIDPOST_VERSION=2.14
ARG GIDPOST_SHA256=43a3d907558503b3248abe6d61e39f1d45430ac98573489af25cbff5e8e82f37
ARG BUILD_JOBS=2

# Build GiDPost from its official release, including its Fortran C bindings.
RUN curl -fsSL --retry 3 \
        "https://downloads.gidsimulation.com/Tools/gidpost/gidpost-${GIDPOST_VERSION}.zip" \
        -o /tmp/gidpost.zip \
    && printf '%s  %s\n' "${GIDPOST_SHA256}" /tmp/gidpost.zip | sha256sum -c - \
    && unzip -q /tmp/gidpost.zip -d /tmp \
    # Upstream 2.14 finds HDF5 HL but omits it from the library link dependencies.
    && printf '\ntarget_link_libraries(gidpost ${HDF5_HL_LIBRARIES})\n' \
        >> "/tmp/gidpost-${GIDPOST_VERSION}/source/CMakeLists.txt" \
    && cmake -S "/tmp/gidpost-${GIDPOST_VERSION}" -B /tmp/gidpost-build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_FLAGS=-DgFortran \
        -DCMAKE_SHARED_LINKER_FLAGS=-Wl,--no-undefined \
        -DENABLE_HDF5=ON \
        -DENABLE_SHARED_LIBS=ON \
        -DENABLE_EXAMPLES=OFF \
        -DENABLE_FORTRAN_EXAMPLES=OFF \
    && cmake --build /tmp/gidpost-build --parallel "${BUILD_JOBS}" \
    && cmake --install /tmp/gidpost-build \
    && install -D -m 644 "/tmp/gidpost-${GIDPOST_VERSION}/fortran_module/gidpost_interface.f90" \
        /usr/local/share/gidpost/gidpost_interface.f90 \
    && install -D -m 644 "/tmp/gidpost-${GIDPOST_VERSION}/LICENSE" \
        /usr/local/share/licenses/gidpost/LICENSE \
    && ldconfig \
    && rm -rf /tmp/gidpost.zip "/tmp/gidpost-${GIDPOST_VERSION}" /tmp/gidpost-build

COPY modulefiles/ /usr/local/share/hofem/modulefiles/
COPY docker/configure-modules.py /usr/local/sbin/hofem-configure-modules
RUN python3 /usr/local/sbin/hofem-configure-modules gnu
COPY docker/entrypoint.sh /usr/local/bin/hofem-entrypoint
COPY tests/smoke.sh /usr/local/bin/hofem-smoke-test
RUN chmod 755 /usr/local/bin/hofem-entrypoint /usr/local/bin/hofem-smoke-test \
    && useradd --create-home --uid 10001 --shell /bin/bash developer \
    && mkdir -p /workspace \
    && chown developer:developer /workspace \
    && printf '\nsource /etc/profile.d/lmod.sh\n' >> /etc/bash.bashrc

WORKDIR /workspace
USER developer
ENTRYPOINT ["/usr/local/bin/hofem-entrypoint"]
CMD ["/bin/bash"]

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
USER root
# Resolve current release series from APT metadata, then install payload packages.
RUN bash /usr/local/sbin/hofem-install-intel latest

USER developer
