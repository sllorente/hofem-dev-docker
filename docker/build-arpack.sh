#!/bin/bash
set -eo pipefail

serial_prefix=${1:?Specify the ARPACK installation prefix}
parallel_prefix=${2:?Specify the PARPACK installation prefix}
: "${FC:?Load an Intel compiler module first}"
: "${MPIFC:?Load the matching Intel MPI module first}"
: "${MPIROOT:?Load the matching Intel MPI module first}"
archive=${ARPACK_ARCHIVE:-/usr/local/share/hofem/sources/arpack-97.tar.gz}
sha256=3c0e71948573d61147a0f25c15a83f5ed4ed1fcbb01b244d5e12477618781f82
printf '%s  %s\n' "$sha256" "$archive" | sha256sum -c -
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
tar -xzf "$archive" -C "$build_dir"
src=$build_dir/ARPACK

# README: configure ARmake.inc, use installed BLAS/LAPACK, then make lib/plib.
# The bundled timer already uses the portable CPU_TIME intrinsic.
python3 - "$src" "$FC" "$MPIFC" <<'PY'
from pathlib import Path
import re
import sys
root, fc, mpifc = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
p = root / 'ARmake.inc'
s = p.read_text()
values = {
    'home': str(root), 'PLAT': 'intel', 'COMMLIB': 'MPI',
    'DIRS': '$(UTILdir) $(SRCdir)',
    'ARPACKLIB': '$(home)/libarpack.a', 'PARPACKLIB': '$(home)/libparpack.a',
    'FC': fc, 'PFC': mpifc, 'FFLAGS': '-O2 -fPIC', 'PFFLAGS': '-O2 -fPIC',
    'ARFLAGS': 'rcs', 'RANLIB': 'ranlib',
}
for key, value in values.items():
    pattern = r'^' + re.escape(key) + r'\s*=.*$'
    if re.search(pattern, s, flags=re.M):
        s = re.sub(pattern, key + ' = ' + value, s, flags=re.M)
    else:
        s += '\n' + key + ' = ' + value + '\n'
p.write_text(s)
# GNU Make rejects the spaces preceding the unused upstream help recipe.
p = root / 'Makefile'
p.write_text(p.read_text().replace('    @$(ECHO)', '\t@$(ECHO)'))
PY

# README: supply the vendor MPI include file in each MPI source/example directory.
for directory in PARPACK/SRC/MPI PARPACK/UTIL/MPI PARPACK/EXAMPLES/MPI; do
    cp "$MPIROOT/include/mpif.h" "$src/$directory/mpif.h"
done
# Serial make avoids simultaneous updates of one archive by precision targets.
make -C "$src" -j1 lib
# These MPI makefiles use FC/FFLAGS, rather than PFC/PFFLAGS, for compilation.
make -C "$src" -j1 plib "FC=$MPIFC" 'FFLAGS=-O2 -fPIC'

install -d "$serial_prefix/lib" "$serial_prefix/include" "$parallel_prefix/lib" "$parallel_prefix/include"
install -m 644 "$src/libarpack.a" "$serial_prefix/lib/"
install -m 644 "$src/libparpack.a" "$parallel_prefix/lib/"
install -m 644 "$src/SRC/"*.h "$serial_prefix/include/"
install -m 644 "$src/PARPACK/SRC/MPI/debug.h" "$src/PARPACK/SRC/MPI/stat.h" "$parallel_prefix/include/"
# MKL uses LP64 integers by default, matching the archive's default INTEGER ABI.
"$FC" -fPIC -shared -Wl,--no-undefined -Wl,-soname,libarpack.so \
    -Wl,--whole-archive "$serial_prefix/lib/libarpack.a" -Wl,--no-whole-archive \
    -qmkl=sequential -o "$serial_prefix/lib/libarpack.so"
"$MPIFC" -fPIC -shared -Wl,--no-undefined -Wl,-soname,libparpack.so \
    -Wl,--whole-archive "$parallel_prefix/lib/libparpack.a" -Wl,--no-whole-archive \
    -L "$serial_prefix/lib" -larpack -qmkl=sequential \
    -Wl,-rpath,"$serial_prefix/lib" -o "$parallel_prefix/lib/libparpack.so"

for prefix in "$serial_prefix" "$parallel_prefix"; do
    install -D -m 644 "$src/README" "$prefix/share/arpack/README"
    install -m 644 "$src/ARmake.inc" "$prefix/share/arpack/ARmake.inc"
    printf '%s\n' "$sha256" > "$prefix/share/arpack/archive-sha256"
done
