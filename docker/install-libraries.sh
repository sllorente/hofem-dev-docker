#!/bin/bash
set -eo pipefail
# Refuse GNU-only and single-Intel bases before compiling any libraries.
test -f /usr/local/share/hofem/three-stacks
test -f /usr/local/share/hofem/intel/2025.3.toolchain
test -f /usr/local/share/hofem/intel/latest.toolchain
python3 - <<'PY'
from pathlib import Path
root = Path('/usr/local/share/hofem/intel')
compilers = { (root / (p + '.toolchain')).read_text().split()[0] for p in ('2025.3', 'latest') }
if len(compilers) != 2:
    raise SystemExit('hofem-dev requires two distinct Intel compiler series plus GNU')
PY
python3 /usr/local/sbin/hofem-configure-modules gidpost
source /etc/profile.d/lmod.sh
module purge
module load gfortran openmpi
for version in $GIDPOST_VERSIONS; do
    module load "gidpost/$version"
    GIDPOST_VERSION="$version" bash /usr/local/sbin/hofem-build-gidpost "$GRF_GIDPOSTROOT" "$CC" "$CXX" "$FC"
    module unload gidpost
done
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    module purge
    module load "oneapi/compiler/$compiler" "impi/$mpi"
    for version in $GIDPOST_VERSIONS; do
        module load "gidpost/$version"
        GIDPOST_VERSION="$version" bash /usr/local/sbin/hofem-build-gidpost "$GRF_GIDPOSTROOT" "$CC" "$CXX" "$FC"
        module unload gidpost
    done
done
module purge
