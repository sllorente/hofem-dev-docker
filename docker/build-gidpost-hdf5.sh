#!/bin/bash
set -eo pipefail
prefix=${1:?Specify the private HDF5 prefix}
: "${CC:?Load a compiler module}"
archive=${HDF5_ARCHIVE:-/usr/local/share/hofem/sources/hdf5-1.10.10.tar.gz}
sha256=a6877ab7bd5d769d2d68618fdb54beb50263dcc2a8c157fe7e2186925cdb02db
printf '%s  %s\n' "$sha256" "$archive" | sha256sum -c -
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
tar -xzf "$archive" -C "$build_dir"
cmake -S "$build_dir/hdf5-1.10.10" -B "$build_dir/build" \
    -DCMAKE_INSTALL_PREFIX="$prefix" -DHDF5_INSTALL_LIB_DIR=lib \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_C_FLAGS=-fPIC -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON -DONLY_SHARED_LIBS=OFF \
    -DHDF5_BUILD_HL_LIB=ON -DHDF5_BUILD_CPP_LIB=OFF -DHDF5_BUILD_FORTRAN=OFF \
    -DHDF5_BUILD_JAVA=OFF -DHDF5_BUILD_TOOLS=OFF -DHDF5_BUILD_EXAMPLES=OFF \
    -DBUILD_TESTING=OFF -DHDF5_ENABLE_PARALLEL=OFF -DHDF5_ENABLE_THREADSAFE=ON \
    -DALLOW_UNSUPPORTED=ON \
    -DHDF5_ENABLE_Z_LIB_SUPPORT=ON -DHDF5_ENABLE_SZIP_SUPPORT=ON \
    -DHDF5_ENABLE_SZIP_ENCODING=ON -DHDF5_ENABLE_ROS3_VFD=OFF -DHDF5_ENABLE_HDFS=OFF
cmake --build "$build_dir/build" --parallel "${BUILD_JOBS:-2}"
cmake --install "$build_dir/build"
install -D -m 644 "$build_dir/build/compile_commands.json" "$prefix/share/hdf5/compile_commands.json"
install -m 644 "$build_dir/hdf5-1.10.10/COPYING" "$prefix/share/hdf5/"
python3 - "$prefix" "$sha256" <<'PY'
from pathlib import Path
import json, os, sys
root = Path(sys.argv[1])/'share/hdf5'
commands = json.loads((root/'compile_commands.json').read_text())
assert commands and all('-fPIC' in c['command'] for c in commands)
config = dict(version='1.10.10', archive_sha256=sys.argv[2], compiler=os.environ['CC'],
              pic=True, static=True, shared=True, high_level=True, mpi=False,
              threadsafe=True, hl_thread_safety_guaranteed=False,
              compression=['zlib','szip'], purpose='GiDPost private dependency')
(root/'build-config.json').write_text(json.dumps(config,indent=2)+'\n')
PY
