#!/bin/bash
set -eo pipefail
prefix=${1:?Specify the GiDPost prefix}
hdf5=${2:?Specify the PIC HDF5 prefix}
: "${CC:?Load the matching compiler}"
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
metadata=$prefix/share/gidpost
mkdir -p "$metadata"
# Preserve the original archive for idempotent relinking and provenance.
original=$metadata/libgidpost-unbundled.a
if [[ ! -f $original ]]; then cp "$prefix/lib/libgidpost.a" "$original"; fi
test -s "$hdf5/lib/libhdf5.a"
test -s "$hdf5/lib/libhdf5_hl.a"
ld -r --whole-archive "$original" "$hdf5/lib/libhdf5_hl.a" "$hdf5/lib/libhdf5.a" \
    --no-whole-archive -o "$build_dir/combined.o"
# Resolve references inside one relocatable object, then make the embedded HDF5
# symbols private. This avoids collisions with an application's own HDF5.
nm -g --defined-only --format=posix "$hdf5/lib/libhdf5.a" "$hdf5/lib/libhdf5_hl.a" \
    | awk '$2 ~ /^[A-Za-z]$/ && $2 !~ /^[Uu]$/ {print $1}' | sort -u > "$build_dir/hdf5-symbols"
test -s "$build_dir/hdf5-symbols"
objcopy --localize-symbols="$build_dir/hdf5-symbols" "$build_dir/combined.o"
ar rcs "$build_dir/libgidpost.a" "$build_dir/combined.o"
"$CC" -fPIC -shared -Wl,--no-undefined -Wl,-soname,libgidpost.so \
    "$build_dir/combined.o" -lsz -lz -ldl -lpthread -lm -o "$build_dir/libgidpost.so"
install -m 644 "$build_dir/libgidpost.a" "$build_dir/libgidpost.so" "$prefix/lib/"
install -D -m 644 "$hdf5/share/hdf5/COPYING" "$prefix/share/licenses/hdf5/COPYING"
python3 - "$metadata" "$hdf5" <<'PY'
from pathlib import Path
import json, sys
root, hdf5 = map(Path, sys.argv[1:])
config = json.loads((hdf5/'share/hdf5/build-config.json').read_text())
config.update(hdf5_prefix=str(hdf5), embedded_static_archive=True,
              embedded_shared_library=True, hdf5_symbols_private=True)
(root/'embedded-hdf5.json').write_text(json.dumps(config,indent=2)+'\n')
PY
