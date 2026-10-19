#!/bin/bash
set -eo pipefail

prefix=${1:?Specify the installation prefix}
cc=${2:?Specify the C compiler}
cxx=${3:?Specify the C++ compiler}
fc=${4:?Specify the Fortran compiler}
version=${GIDPOST_VERSION:-2.14}
case "$version" in
    2.14) sha256=d518bb622d9a8501e5ab7bf1f4dc4092db80f1e8cabe30ba177811d77d85e7bc ;;
    2.9) sha256=edfdde3a84eda7923f7713a7e2cbab7bce2cc3d740587aef90514562c4993eb5 ;;
    *) printf 'Unsupported GiDPost version: %s\n' "$version" >&2; exit 1 ;;
esac
source_dir="${GIDPOST_SOURCE_ROOT:-/usr/local/src}/gidpost-${version}"
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT

# Reuse a GNU installation of the requested version, even if it predates this script.
# An existing version does not replace a different requested release.
if [[ ${cc##*/} == gcc ]]; then
    for candidate in "$prefix" /usr/local; do
        header="$candidate/include/gidpost.h"
        [[ -f $header ]] || continue
        installed=$(awk '{gsub(/\r/, "")} /^#define GP_VERSION_MAJOR / {major=$3} /^#define GP_VERSION_MINOR / {minor=$3} END {print major "." minor}' "$header")
        if [[ $installed == "$version" ]] && [[ -f $candidate/lib/libgidpost.a || -f $candidate/lib/libgidpost.so ]]; then
            mkdir -p /usr/local/share/hofem/gidpost
            printf '%s\n' "$candidate" > "/usr/local/share/hofem/gidpost/gnu-${version}.prefix"
            printf 'Reusing GNU GiDPost %s from %s\n' "$version" "$candidate"
            exit 0
        fi
    done
fi

if [[ ! -d $source_dir ]]; then
    archive=${GIDPOST_ARCHIVE:-/usr/local/share/hofem/sources/gidpost-${version}.tar.gz}
    if [[ ! -f $archive ]]; then
        printf 'Required local GiDPost source archive is missing: %s\n' "$archive" >&2
        exit 1
    fi
    printf '%s  %s\n' "$sha256" "$archive" | sha256sum -c -
    tar -xzf "$archive" -C "$build_dir"
    mkdir -p "$source_dir"
    for item in CMakeLists.txt gidpost_config.h.in source cfortran fortran_module LICENSE; do
        cp -a "$build_dir/gidpost-${version}/$item" "$source_dir/"
    done
    printf '%s\n' "$sha256" > "$source_dir/.archive-sha256"
fi
test "$(cat "$source_dir/.archive-sha256")" = "$sha256"

# Both releases omit HDF5 HL from their link dependencies. Apply fixes idempotently
# so retained sources can be reused across compiler stacks.
python3 - "$source_dir" "$version" <<'PY'
from pathlib import Path
import re
import sys
root, version = Path(sys.argv[1]), sys.argv[2]
p = root / 'source/CMakeLists.txt'
s = p.read_text()
if 'target_link_libraries(gidpost ${HDF5_HL_LIBRARIES})' not in s:
    p.write_text(s + '\ntarget_link_libraries(gidpost ${HDF5_HL_LIBRARIES})\n')
p = root / 'CMakeLists.txt'
s = p.read_text()
# Only library inputs are retained; upstream 2.9 unconditionally adds examples.
s = re.sub(r'^\s*add_subdirectory\s*\(\s*examples[^\n]*', '', s, flags=re.M | re.I)
if version == '2.9':
    (root / 'source/gidpost_config.h').unlink(missing_ok=True)
    s = re.sub(r'set\s*\(GP_VERSION_MINOR\s+8\)', 'set (GP_VERSION_MINOR 9)', s)
p.write_text(s)
PY

cflags='-fPIC -DgFortran'
if [[ $version == 2.9 && ${cc##*/} == icx ]]; then
    # Upstream's legacy GiD_fWriteResultBlock wrapper has an incompatible pointer
    # argument. Keep its warning visible; this flag does not repair that API.
    cflags+=' -Wno-error=incompatible-pointer-types'
fi
for variant in static shared; do
    shared=OFF
    [[ $variant != shared ]] || shared=ON
    cmake -S "$source_dir" -B "$build_dir/$variant" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DCMAKE_C_COMPILER="$cc" -DCMAKE_CXX_COMPILER="$cxx" \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_C_FLAGS="$cflags" \
        -DCMAKE_CXX_FLAGS=-fPIC -DCMAKE_SHARED_LINKER_FLAGS=-Wl,--no-undefined \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DENABLE_HDF5=ON \
        -DENABLE_SHARED_LIBS="$shared" -DENABLE_EXAMPLES=OFF -DENABLE_FORTRAN_EXAMPLES=OFF
    cmake --build "$build_dir/$variant" --target gidpost --parallel "${BUILD_JOBS:-2}"
    cmake --install "$build_dir/$variant"
    install -D -m 644 "$build_dir/$variant/compile_commands.json" \
        "$prefix/share/gidpost/compile_commands-${variant}.json"
done

install -D -m 644 "$source_dir/fortran_module/gidpost_interface.f90" \
    "$prefix/share/gidpost/gidpost_interface.f90"
install -D -m 644 "$source_dir/LICENSE" "$prefix/share/licenses/gidpost/LICENSE"
module_flags=(-J "$prefix/include")
if [[ ${fc##*/} == ifx ]]; then module_flags=(-module "$prefix/include"); fi
"$fc" -fPIC "${module_flags[@]}" -c "$prefix/share/gidpost/gidpost_interface.f90" \
    -o "$build_dir/gidpost_interface.o"
ar rcs "$prefix/lib/libgidpost_fortran.a" "$build_dir/gidpost_interface.o"
"$fc" -fPIC -shared -Wl,--no-undefined "$build_dir/gidpost_interface.o" \
    -L "$prefix/lib" -lgidpost -o "$prefix/lib/libgidpost_fortran.so"
if [[ ${cc##*/} == gcc ]]; then
    mkdir -p /usr/local/share/hofem/gidpost
    printf '%s\n' "$prefix" > "/usr/local/share/hofem/gidpost/gnu-${version}.prefix"
fi
if [[ $prefix == /usr/local ]]; then ldconfig; fi
