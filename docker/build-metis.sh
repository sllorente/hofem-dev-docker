#!/bin/bash
set -eo pipefail
prefix=${1:?Specify the installation prefix}
: "${CC:?Load the Intel compiler module first}"
: "${CXX:?Load the Intel compiler module first}"
archive=${METIS_ARCHIVE:-/usr/local/share/hofem/sources/metis-5.1.0.tar.gz}
sha256=76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2
printf '%s  %s\n' "$sha256" "$archive" | sha256sum -c -
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
tar -xzf "$archive" -C "$build_dir"
src=$build_dir/metis-5.1.0
# The selected ABI is upstream's default; fail rather than silently change it.
python3 - "$src/include/metis.h" <<'PY'
from pathlib import Path
import re
import sys
header = Path(sys.argv[1]).read_text()
for name in ('IDXTYPEWIDTH', 'REALTYPEWIDTH'):
    assert re.search(r'^#define\s+' + name + r'\s+32\s*$', header, re.M), name
PY
for variant in static shared; do
    shared=OFF
    [[ $variant != shared ]] || shared=ON
    # BUILD.txt's make config delegates to these CMake options. Separate build
    # directories preserve both variants, which the upstream wrapper overwrites.
    cmake -S "$src" -B "$build_dir/$variant" \
        -DGKLIB_PATH="$src/GKlib" -DSHARED="$shared" \
        -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
        -DCMAKE_C_FLAGS=-fPIC -DCMAKE_CXX_FLAGS=-fPIC \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DCMAKE_SHARED_LINKER_FLAGS=-Wl,--no-undefined \
        -DOPENMP=OFF -DGDB=OFF -DDEBUG=OFF -DASSERT=OFF -DASSERT2=OFF -DGPROF=OFF
    cmake --build "$build_dir/$variant" --parallel "${BUILD_JOBS:-2}"
    cmake --install "$build_dir/$variant"
    install -D -m 644 "$build_dir/$variant/compile_commands.json" \
        "$prefix/share/metis/compile_commands-$variant.json"
done
install -m 644 "$src/BUILD.txt" "$src/Install.txt" "$src/LICENSE.txt" "$prefix/share/metis/"
python3 - "$prefix" "$sha256" "$CC" <<'PY'
from pathlib import Path
import json
import sys
prefix, checksum, compiler = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
config = dict(version='5.1.0', index_bits=32, real_bits=32, openmp=False,
              build_type='Release', assertions=False, profiling=False,
              static=True, shared=True, pic=True, archive_sha256=checksum,
              compiler=compiler)
(prefix / 'share/metis/build-config.json').write_text(json.dumps(config, indent=2) + '\n')
PY
