#!/bin/bash
set -eo pipefail
grema-smoke-test --with-libraries
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cd "$test_dir"
source /etc/profile.d/lmod.sh
cat > gidpost.c <<'EOF'
#include <gidpost.h>
int main(void) {
    GiD_FILE file;
    if (GiD_PostInit() != 0) return 1;
    file = GiD_fOpenPostResultFile("smoke.post.res", GiD_PostAscii);
    if (!file || GiD_fClosePostResultFile(file) != 0) return 2;
    file = GiD_fOpenPostResultFile("smoke.post.h5", GiD_PostHDF5);
    if (!file || GiD_fClosePostResultFile(file) != 0) return 3;
    return GiD_PostDone();
}
EOF
cat > gidpost.f90 <<'EOF'
program fortran_gidpost_smoke
  use gidpost
  implicit none
  type(GiD_File) :: file
  call GiD_PostInit()
  file = GiD_fOpenPostResultFile("fortran.post.res", GiD_PostAscii)
  call GiD_fClosePostResultFile(file)
  call GiD_PostDone()
end program
EOF

check_gidpost() {
    local c_compiler=$1
    "$c_compiler" -fPIC -I "$GRF_GIDPOSTINC" gidpost.c -L "$GRF_GIDPOSTLIB" -lgidpost -o gidpost-smoke
    ldd ./gidpost-smoke | grep -F "$GRF_GIDPOSTLIB/libgidpost.so"
    ./gidpost-smoke
    test -s smoke.post.res
    test -s smoke.post.h5
    "$FC" -fPIC -I "$GRF_GIDPOSTINC" gidpost.f90 -L "$GRF_GIDPOSTLIB" \
        -lgidpost_fortran -lgidpost -o fortran-gidpost-smoke
    ./fortran-gidpost-smoke
    test -s fortran.post.res
    if [[ -f $GRF_GIDPOSTLIB/libgidpost.a ]]; then
        "$c_compiler" -fPIC -I "$GRF_GIDPOSTINC" gidpost.c \
            "$GRF_GIDPOSTLIB/libgidpost.a" $(pkg-config --libs hdf5) \
            -lhdf5_hl -lz -lpthread -lm -o gidpost-static-smoke
        ./gidpost-static-smoke
        "$FC" -fPIC -I "$GRF_GIDPOSTINC" gidpost.f90 \
            "$GRF_GIDPOSTLIB/libgidpost_fortran.a" "$GRF_GIDPOSTLIB/libgidpost.a" \
            $(pkg-config --libs hdf5) -lhdf5_hl -lz -lpthread -lm -o fortran-static-smoke
        ./fortran-static-smoke
        test -s "$GRF_GIDPOSTLIB/libgidpost_fortran.so"
        "$c_compiler" -fPIC -shared -Wl,--no-undefined \
            -Wl,--whole-archive "$GRF_GIDPOSTLIB/libgidpost.a" -Wl,--no-whole-archive \
            $(pkg-config --libs hdf5) -lhdf5_hl -lz -lpthread -lm -o gidpost-static-pic-check.so
    else
        # A reused GNU installation may predate the requirement for both variants.
        test "$CC" = gcc
        test "$(cat "/usr/local/share/hofem/gidpost/gnu-${GRF_GIDPOST_VERSION}.prefix")" = "$GRF_GIDPOSTROOT"
    fi
    # Link the complete static Fortran interface into a shared library to verify PIC.
    "$FC" -fPIC -shared -Wl,--whole-archive "$GRF_GIDPOSTLIB/libgidpost_fortran.a" \
        -Wl,--no-whole-archive -L "$GRF_GIDPOSTLIB" -lgidpost -o fortran-pic-check.so
}

check_versions() {
    for gidpost_version in $GIDPOST_VERSIONS; do
        module load "gidpost/$gidpost_version"
        test "$GRF_GIDPOST_VERSION" = "$gidpost_version"
        check_gidpost "$CC"
        module unload gidpost
    done
}
module purge
module load gfortran openmpi
check_versions
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    module purge
    module load "oneapi/compiler/$compiler" "impi/$mpi"
    check_versions
done
module purge
printf 'HOFEM GiDPost smoke tests passed.\n'
hofem-arpack-test
hofem-metis-test
hofem-parmetis-test
hofem-scotch-test
hofem-mumps-test
