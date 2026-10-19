#!/bin/bash
set -eo pipefail
python3 - <<'PY'
from pathlib import Path
import os, re
root = Path('/opt/modulefiles')
gnu, mpi = (root/'gnu.toolchain').read_text().split()
header = Path('/usr/include/dmumps_c.h').read_text()
version = re.search(r'^#define\s+MUMPS_VERSION\s+"([^"]+)"',header,re.M)[1]
modules = [(f"gcc/{gnu.split('.')[0]}/openmpi/{mpi.split('.')[0]}",version)]
for profile in Path('/usr/local/share/hofem/intel').glob('*.toolchain'):
    compiler, mpi, _ = profile.read_text().split()
    modules.append((f"intel/{compiler.split('.')[0]}/impi/{mpi.split('.')[0]}",'5.7.3'))
for hierarchy, version in modules:
    target = root/'MPI'/hierarchy/'mumps'/f'{version}.lua'
    target.parent.mkdir(parents=True,exist_ok=True)
    target.unlink(missing_ok=True)
    target.symlink_to(os.path.relpath(root/'MPI/generic.lua',target.parent))
PY
mkdir -p /usr/local/share/hofem/mumps
dpkg-query -W -f='${Package}\t${Version}\n' libmumps-dev libmumps-headers-dev \
    > /usr/local/share/hofem/mumps/gnu.packages
source /etc/profile.d/lmod.sh
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    module purge
    module load "oneapi/compiler/$compiler" "impi/$mpi" metis parmetis scotch ptscotch mumps/5.7.3
    bash /usr/local/sbin/hofem-build-mumps "$GRF_MUMPSROOT"
done
module purge
