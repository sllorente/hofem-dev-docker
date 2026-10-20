#!/bin/bash
set -eo pipefail
# Require GNU and at least one Intel profile; build only the installed stacks.
test -s /opt/modulefiles/gnu.toolchain
python3 - <<'PY'
from pathlib import Path
root = Path('/usr/local/share/hofem/intel')
profiles = sorted(root.glob('*.toolchain'))
if not profiles:
    raise SystemExit('hofem-dev requires GNU and at least one Intel compiler/MPI profile')
for profile in profiles:
    compiler, mpi, mkl = profile.read_text().split()
    for component, version in (('compiler',compiler), ('mpi',mpi), ('mkl',mkl)):
        variables = Path('/opt/intel/oneapi')/component/version/'env/vars.sh'
        if not variables.is_file():
            raise SystemExit(f'{profile.name}: missing toolchain component: {variables}')
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
