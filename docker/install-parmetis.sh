#!/bin/bash
set -eo pipefail
python3 - <<'PY'
from pathlib import Path
import os
root = Path('/opt/modulefiles')
gnu, mpi = (root / 'gnu.toolchain').read_text().split()
hierarchies = {f"gcc/{gnu.split('.')[0]}/openmpi/{mpi.split('.')[0]}"}
for profile in Path('/usr/local/share/hofem/intel').glob('*.toolchain'):
    compiler, mpi, _ = profile.read_text().split()
    hierarchies.add(f"intel/{compiler.split('.')[0]}/impi/{mpi.split('.')[0]}")
for hierarchy in sorted(hierarchies):
    target = root / 'MPI' / hierarchy / 'parmetis/4.0.3.lua'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.unlink(missing_ok=True)
    target.symlink_to(os.path.relpath(root / 'MPI/generic.lua', target.parent))
PY
# Reuse GNU's original ParMETIS 4.0.3 and OpenMPI installation.
mkdir -p /usr/local/share/hofem/parmetis
dpkg-query -W -f='${Package}\t${Version}\n' libparmetis-dev \
    > /usr/local/share/hofem/parmetis/gnu.packages
test -s /usr/lib/libparmetis.a
test -e /usr/lib/libparmetis.so
source /etc/profile.d/lmod.sh
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    module purge
    module load "oneapi/compiler/$compiler" "impi/$mpi" metis/5.1.0 parmetis/4.0.3
    bash /usr/local/sbin/hofem-build-parmetis "$GRF_PARMETISROOT"
done
module purge
