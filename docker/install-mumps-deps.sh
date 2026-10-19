#!/bin/bash
set -eo pipefail
packages=()
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    # Add only ScaLAPACK/BLACS payloads, matching the already installed core.
    version=$(dpkg-query -W -f='${Version}' "intel-oneapi-mkl-core-devel-$mkl")
    packages+=("intel-oneapi-mkl-cluster-devel-$mkl=$version" "intel-oneapi-mkl-cluster-$mkl=$version")
done
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
mkdir -p /usr/local/share/hofem/mumps
dpkg-query -W -f='${Package}\t${Version}\n' 'intel-oneapi-mkl-cluster*' \
    > /usr/local/share/hofem/mumps/intel-cluster.packages
rm -rf /var/lib/apt/lists/*
