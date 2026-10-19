#!/bin/bash
set -eo pipefail
prefix=${1:?Specify the ParMETIS installation prefix}
: "${MPICC:?Load an Intel MPI module first}"
: "${MPICXX:?Load an Intel MPI module first}"
: "${GRF_METISROOT:?Load the matching METIS module first}"
archive=${PARMETIS_ARCHIVE:-/usr/local/share/hofem/sources/parmetis-4.0.3.tar.gz}
sha256=f2d9a231b7cf97f1fee6e8c9663113ebf6c240d407d3c118c55b3633d6be6e5f
printf '%s  %s\n' "$sha256" "$archive" | sha256sum -c -
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
tar -xzf "$archive" -C "$build_dir"
src=$build_dir/parmetis-4.0.3
# Keep the upstream CMake symlink operation inside the temporary build tree.
cd "$build_dir"
python3 - "$src" "$GRF_METISROOT" <<'PY'
from pathlib import Path
import json
import sys
root, metis = Path(sys.argv[1]), Path(sys.argv[2])
config = json.loads((metis / 'share/metis/build-config.json').read_text())
assert config['version'] == '5.1.0' and config['index_bits'] == config['real_bits'] == 32
assert config['openmp'] is False and config['pic'] is True
assert config['archive_sha256'] == '76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2'
assert (root / 'metis/include/metis.h').read_bytes() == (metis / 'include/metis.h').read_bytes()
# Reuse the matching compiler's METIS instead of compiling the bundled duplicate.
p = root / 'CMakeLists.txt'
s = p.read_text()
old = 'add_subdirectory(${METIS_PATH}/libmetis ${CMAKE_BINARY_DIR}/libmetis)'
assert s.count(old) == 1
s = s.replace(old, '''add_library(metis UNKNOWN IMPORTED)
set_target_properties(metis PROPERTIES
  IMPORTED_LOCATION "${HOFEM_METIS_LIBRARY}"
  INTERFACE_LINK_LIBRARIES "m")''')
p.write_text(s)
PY
for variant in static shared; do
    shared=OFF
    metis_library="$GRF_METISLIB/libmetis.a"
    if [[ $variant == shared ]]; then shared=ON; metis_library="$GRF_METISLIB/libmetis.so"; fi
    cmake -S "$src" -B "$build_dir/$variant" \
        -DGKLIB_PATH="$src/metis/GKlib" -DMETIS_PATH="$src/metis" \
        -DHOFEM_METIS_LIBRARY="$metis_library" -DSHARED="$shared" \
        -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="$MPICC" -DCMAKE_CXX_COMPILER="$MPICXX" \
        -DCMAKE_C_FLAGS=-fPIC -DCMAKE_CXX_FLAGS=-fPIC \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DCMAKE_SHARED_LINKER_FLAGS=-Wl,--no-undefined \
        -DCMAKE_INSTALL_RPATH="$prefix/lib;$GRF_METISLIB" \
        -DOPENMP=OFF -DGDB=OFF -DDEBUG=OFF -DASSERT=OFF -DASSERT2=OFF -DGPROF=OFF
    cmake --build "$build_dir/$variant" --parallel "${BUILD_JOBS:-2}"
    cmake --install "$build_dir/$variant"
    install -D -m 644 "$build_dir/$variant/compile_commands.json" \
        "$prefix/share/parmetis/compile_commands-$variant.json"
done
install -m 644 "$src/BUILD.txt" "$src/Install.txt" "$src/LICENSE.txt" "$src/CMakeLists.txt" "$prefix/share/parmetis/"
python3 - "$prefix" "$sha256" "$GRF_METISROOT" "$MPIROOT" "$MPICC" <<'PY'
from pathlib import Path
import json
import sys
prefix, checksum, metis, mpi, compiler = sys.argv[1:]
config = dict(version='4.0.3', index_bits=32, real_bits=32, openmp=False,
              build_type='Release', assertions=False, profiling=False,
              static=True, shared=True, pic=True, archive_sha256=checksum,
              metis_prefix=metis, mpi_root=mpi, compiler=compiler,
              bundled_metis_rebuilt=False)
(Path(prefix) / 'share/parmetis/build-config.json').write_text(json.dumps(config, indent=2) + '\n')
PY
