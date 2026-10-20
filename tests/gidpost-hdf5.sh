#!/bin/bash
set -eo pipefail
source /etc/profile.d/lmod.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
cat > check.c <<'C'
#include <gidpost.h>
int main(void) {
    if (GiD_PostInit() != 0) return 1;
    GiD_FILE file = GiD_fOpenPostResultFile("c.post.h5", GiD_PostHDF5);
    if (!file || GiD_fClosePostResultFile(file) != 0) return 2;
    return GiD_PostDone();
}
C
cat > check.f90 <<'F90'
program check
  use gidpost
  implicit none
  type(GiD_File) :: file
  call GiD_PostInit()
  file = GiD_fOpenPostResultFile('fortran.post.h5', GiD_PostHDF5)
  call GiD_fClosePostResultFile(file)
  call GiD_PostDone()
end program
F90
cat > read.c <<'C'
#include <hdf5.h>
int main(int argc, char **argv) {
    for (int i=1; i<argc; ++i) {
        if (H5Fis_hdf5(argv[i]) <= 0) return 1;
        hid_t file = H5Fopen(argv[i], H5F_ACC_RDONLY, H5P_DEFAULT);
        if (file < 0 || H5Fclose(file) < 0) return 2;
    }
    return 0;
}
C
# Read with the independently installed system HDF5, not the embedded copy.
gcc -fPIC $(pkg-config --cflags hdf5) read.c $(pkg-config --libs hdf5) -o read-check
check_stack() {
    local version variant
    local -a c_libraries f_libraries deps
    deps=(-lsz -lz -ldl -lpthread -lm)
    for version in $GIDPOST_VERSIONS; do
        module load "gidpost/$version"
        python3 - "$GRF_GIDPOSTLIB" "$GRF_GIDPOSTROOT" <<'PY'
from pathlib import Path
import json, re, subprocess, sys
lib, root = map(Path, sys.argv[1:])
for name in ('libgidpost.a','libgidpost.so'):
    undefined = subprocess.check_output(['nm','-u',str(lib/name)],text=True)
    assert not any(line.split()[-1].startswith('H5') for line in undefined.splitlines() if line.split()), name
dynamic = subprocess.check_output(['readelf','-d',str(lib/'libgidpost.so')],text=True)
assert 'TEXTREL' not in dynamic
assert not any('NEEDED' in line and 'hdf5' in line.lower() for line in dynamic.splitlines())
def symbols(path, dynamic=False):
    command=['nm','--defined-only','--extern-only','--format=posix']
    if dynamic: command.append('-D')
    output=subprocess.check_output(command+[str(path)],text=True)
    return {line.split()[0] for line in output.splitlines()
            if len(line.split()) >= 2 and len(line.split()[1]) == 1}
original=symbols(root/'share/gidpost/libgidpost-unbundled.a')
assert original <= symbols(lib/'libgidpost.a')
assert original <= symbols(lib/'libgidpost.so',True)
assert not any(s.startswith('H5') for s in symbols(lib/'libgidpost.so',True))
config=json.loads((root/'share/gidpost/embedded-hdf5.json').read_text())
assert config['pic'] and config['hdf5_symbols_private'] and config['threadsafe']
assert config['embedded_static_archive'] and config['embedded_shared_library']
private = Path(config['hdf5_prefix'])
commands=json.loads((private/'share/hdf5/compile_commands.json').read_text())
assert commands and all('-fPIC' in c['command'] for c in commands)
header=(private/'include/H5pubconf.h').read_text()
for feature in ('H5_HAVE_FILTER_DEFLATE','H5_HAVE_FILTER_SZIP','H5_HAVE_THREADSAFE'):
    assert re.search(r'^\s*#\s*define\s+'+feature+r'\s+1\b', header, re.M), feature
print('Verified embedded HDF5, private symbols, preserved GiDPost exports, and no text relocations')
PY
        for variant in shared static; do
            c_libraries=(-L "$GRF_GIDPOSTLIB" -lgidpost)
            f_libraries=(-L "$GRF_GIDPOSTLIB" -lgidpost_fortran -lgidpost)
            if [[ $variant == static ]]; then
                c_libraries=("$GRF_GIDPOSTLIB/libgidpost.a")
                f_libraries=("$GRF_GIDPOSTLIB/libgidpost_fortran.a" "${c_libraries[@]}")
            fi
            "$CC" -fPIC -I "$GRF_GIDPOSTINC" check.c "${c_libraries[@]}" "${deps[@]}" -o c-check
            "$FC" -fPIC -I "$GRF_GIDPOSTINC" check.f90 "${f_libraries[@]}" "${deps[@]}" -o f-check
            ./c-check
            ./f-check
            ./read-check c.post.h5 fortran.post.h5
            ! ldd ./c-check | grep -i hdf5
            ! ldd ./f-check | grep -i hdf5
            rm c.post.h5 fortran.post.h5
            printf 'PASS: %s GiDPost %s %s C/Fortran with embedded HDF5\n' "$CC" "$version" "$variant"
        done
        "$CC" -fPIC -shared -Wl,--no-undefined -Wl,--whole-archive \
            "$GRF_GIDPOSTLIB/libgidpost.a" -Wl,--no-whole-archive "${deps[@]}" -o pic-check.so
        ! readelf -d pic-check.so | grep TEXTREL
        module unload gidpost
    done
}
module purge
module load gfortran
check_stack
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    module purge
    module load "oneapi/compiler/$compiler"
    check_stack
done
module purge
