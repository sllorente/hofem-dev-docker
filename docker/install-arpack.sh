#!/bin/bash
set -eo pipefail
python3 /usr/local/sbin/hofem-configure-modules arpack

# GNU already has both libraries. Reuse them without compiling replacement code.
multiarch=$(gcc -print-multiarch)
for library in arpack parpack; do
    test -s "/usr/lib/$multiarch/lib$library.a"
    test -e "/usr/lib/$multiarch/lib$library.so"
done
mkdir -p /usr/local/share/hofem/arpack
dpkg-query -W -f='${Package}\t${Version}\n' libarpack2-dev libparpack2-dev \
    > /usr/local/share/hofem/arpack/gnu.packages

source /etc/profile.d/lmod.sh
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    module purge
    module load "oneapi/compiler/$compiler" "impi/$mpi" arpack/97 parpack/97
    bash /usr/local/sbin/hofem-build-arpack "$GRF_ARPACKROOT" "$GRF_PARPACKROOT"
done
module purge
