#!/bin/bash
set -eo pipefail
source /etc/profile.d/lmod.sh
embed_stack() {
    local private_prefix version
    module load "gidpost/${GIDPOST_VERSIONS%% *}"
    private_prefix=${GRF_GIDPOSTROOT%/gidpost/*}/gidpost-hdf5/1.10.10
    module unload gidpost
    bash /usr/local/sbin/hofem-build-gidpost-hdf5 "$private_prefix"
    for version in $GIDPOST_VERSIONS; do
        module load "gidpost/$version"
        bash /usr/local/sbin/hofem-embed-gidpost-hdf5 "$GRF_GIDPOSTROOT" "$private_prefix"
        module unload gidpost
    done
}
module purge
module load gfortran
embed_stack
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    module purge
    module load "oneapi/compiler/$compiler"
    embed_stack
done
module purge
