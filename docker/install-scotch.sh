#!/bin/bash
set -eo pipefail
python3 - <<'PY'
from pathlib import Path
import os
import re
root = Path('/opt/modulefiles')
gnu, mpi = (root/'gnu.toolchain').read_text().split()
header = Path('/usr/include/scotch/scotch.h').read_text()
version = '.'.join(re.search(r'^#define\s+SCOTCH_' + field + r'\s+(\d+)',header,re.M)[1]
                   for field in ('VERSION','RELEASE','PATCHLEVEL'))
modules = [(f"Compiler/gcc/{gnu.split('.')[0]}/scotch/{version}.lua",'Compiler/generic.lua'),
           (f"MPI/gcc/{gnu.split('.')[0]}/openmpi/{mpi.split('.')[0]}/ptscotch/{version}.lua",'MPI/generic.lua')]
for profile in Path('/usr/local/share/hofem/intel').glob('*.toolchain'):
    compiler, mpi, _ = profile.read_text().split()
    major = compiler.split('.')[0]
    modules += [(f'Compiler/intel/{major}/scotch/7.0.10.lua','Compiler/generic.lua'),
                (f"MPI/intel/{major}/impi/{mpi.split('.')[0]}/ptscotch/7.0.10.lua",'MPI/generic.lua')]
for relative, template in modules:
    target = root/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    target.unlink(missing_ok=True)
    target.symlink_to(os.path.relpath(root/template,target.parent))
PY
mkdir -p /usr/local/share/hofem/scotch
dpkg-query -W -f='${Package}\t${Version}\n' libscotch-dev libptscotch-dev \
    > /usr/local/share/hofem/scotch/gnu.packages
source /etc/profile.d/lmod.sh
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    module purge
    module load "oneapi/compiler/$compiler" "impi/$mpi" scotch/7.0.10 ptscotch/7.0.10
    bash /usr/local/sbin/hofem-build-scotch "$GRF_SCOTCHROOT" "$GRF_PTSCOTCHROOT"
done
module purge
