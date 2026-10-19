#!/bin/bash
set -eo pipefail
# METIS is serial: its module belongs under Compiler, not under MPI.
python3 - <<'PY'
from pathlib import Path
import os
root = Path('/opt/modulefiles')
gnu, _ = (root / 'gnu.toolchain').read_text().split()
compilers = {'gcc/' + gnu.split('.')[0]}
for profile in Path('/usr/local/share/hofem/intel').glob('*.toolchain'):
    compiler, _, _ = profile.read_text().split()
    compilers.add('intel/' + compiler.split('.')[0])
for compiler in sorted(compilers):
    target = root / 'Compiler' / compiler / 'metis/5.1.0.lua'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.unlink(missing_ok=True)
    target.symlink_to(os.path.relpath(root / 'Compiler/generic.lua', target.parent))
PY
# GNU already has METIS 5.1.0. Preserve it, including its available variants.
mkdir -p /usr/local/share/hofem/metis
dpkg-query -W -f='${Package}\t${Version}\n' libmetis-dev \
    > /usr/local/share/hofem/metis/gnu.packages
python3 - <<'PY'
from pathlib import Path
import re
header = Path('/usr/include/metis.h').read_text()
for key, value in {'METIS_VER_MAJOR': 5, 'METIS_VER_MINOR': 1,
                   'METIS_VER_SUBMINOR': 0, 'IDXTYPEWIDTH': 32, 'REALTYPEWIDTH': 32}.items():
    assert re.search(r'^#define\s+' + key + r'\s+' + str(value) + r'\s*$', header, re.M), key
PY
test -e "/usr/lib/$(gcc -print-multiarch)/libmetis.so"
source /etc/profile.d/lmod.sh
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    module purge
    module load "oneapi/compiler/$compiler" metis/5.1.0
    bash /usr/local/sbin/hofem-build-metis "$GRF_METISROOT"
done
module purge
