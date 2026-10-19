#!/bin/bash
set -eo pipefail
prefix=${1:?Specify the Scotch installation prefix}
parallel_prefix=${2:?Specify the PT-Scotch module prefix}
: "${CC:?Load the Intel compiler}"
: "${MPICC:?Load Intel MPI}"
: "${MPIFC:?Load Intel MPI}"
archive=${SCOTCH_ARCHIVE:-/usr/local/share/hofem/sources/scotch-v7.0.10.tar.gz}
sha256=8327725a08cdd4fc7575e291251883b4f93f75b07a54bc58f89f50dcbba7b244
printf '%s  %s\n' "$sha256" "$archive" | sha256sum -c -
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
tar -xzf "$archive" -C "$build_dir"
src=$build_dir/scotch-v7.0.10
python3 - "$src" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
p = root / 'CMakeLists.txt'
s = p.read_text()
old = 'set(CMAKE_POSITION_INDEPENDENT_CODE ${BUILD_SHARED_LIBS})'
assert s.count(old) == 1
p.write_text(s.replace(old, 'set(CMAKE_POSITION_INDEPENDENT_CODE ON)'))
# The upstream MPI thread probe also compiles source: keep that probe PIC.
p = root / 'cmake/Modules/CheckMpiThreadMultiple.cmake'
s = p.read_text()
old = 'COMMAND ${MPI_C_COMPILER} -o'
assert s.count(old) == 1
p.write_text(s.replace(old, 'COMMAND ${MPI_C_COMPILER} -fPIC -o'))
PY
export I_MPI_FABRICS=shm I_MPI_PIN=0 SCOTCH_PTHREAD_NUMBER=2
for variant in static shared; do
    shared=OFF
    [[ $variant != shared ]] || shared=ON
    cmake -S "$src" -B "$build_dir/$variant" \
        -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS="$shared" \
        -DCMAKE_C_COMPILER="$CC" -DCMAKE_Fortran_COMPILER="$FC" \
        -DMPI_C_COMPILER="$MPICC" -DMPI_Fortran_COMPILER="$MPIFC" \
        -DMPIEXEC_EXECUTABLE="$(command -v mpirun)" \
        -DCMAKE_C_FLAGS=-fPIC -DCMAKE_Fortran_FLAGS=-fPIC \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DINTSIZE=32 -DIDXSIZE=64 -DTHREADS=ON -DMPI_THREAD_MULTIPLE=ON \
        -DSCOTCH_DETERMINISTIC=FIXED_SEED -DBUILD_PTSCOTCH=ON \
        -DBUILD_LIBESMUMPS=ON -DBUILD_FORTRAN=ON -DBUILD_LIBSCOTCHMETIS=OFF \
        -DINSTALL_METIS_HEADERS=OFF -DUSE_ZLIB=ON -DUSE_BZ2=ON -DUSE_LZMA=ON \
        -DENABLE_TESTS=ON -DCMAKE_INSTALL_RPATH="$prefix/lib"
    python3 - "$build_dir/$variant/compile_commands.json" <<'PY'
import json
import sys
commands = json.load(open(sys.argv[1]))
assert commands and all('-fPIC' in c['command'] for c in commands)
assert any('-DSCOTCH_PTHREAD_MPI' in c['command'] for c in commands), 'MPI_THREAD_MULTIPLE probe failed'
assert any('-DSCOTCH_PTHREAD' in c['command'] for c in commands)
PY
    cmake --build "$build_dir/$variant" --parallel "${BUILD_JOBS:-2}"
    # Focused upstream API/strategy and MPI tests; installed-library checks run separately.
    ctest --test-dir "$build_dir/$variant" --output-on-failure --timeout 120 \
        -R '^(test_strat_seq|test_strat_par|test_scotch_graph_order_.*|test_scotch_dgraph_check_.*)$'
    cmake --install "$build_dir/$variant"
    install -D -m 644 "$build_dir/$variant/compile_commands.json" \
        "$prefix/share/scotch/compile_commands-$variant.json"
done
# Keep the upstream combined CMake package coherent and avoid duplicating serial
# libraries: expose the same installation at the MPI hierarchy's PT-Scotch prefix.
mkdir -p "$(dirname "$parallel_prefix")"
ln -s "$prefix" "$parallel_prefix"
install -m 644 "$src/INSTALL.txt" "$src/LICENSE_en.txt" "$prefix/share/scotch/"
python3 - "$prefix" "$parallel_prefix" "$sha256" "$MPIROOT" <<'PY'
from pathlib import Path
import json
import sys
prefix, parallel_prefix, checksum, mpi = sys.argv[1:]
config = dict(version='7.0.10', graph_integer_bits=32, internal_index_bits=64,
              threads=True, mpi_thread_multiple=True, build_type='Release',
              static=True, shared=True, pic=True, fortran=True, esmumps=True,
              metis_compatibility=False, determinism='FIXED_SEED',
              compression=['zlib','bzip2','lzma'], mpi_root=mpi,
              ptscotch_prefix=parallel_prefix, archive_sha256=checksum)
(Path(prefix)/'share/scotch/build-config.json').write_text(json.dumps(config,indent=2)+'\n')
PY
