#!/bin/bash
set -eo pipefail

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cd "$test_dir"

source /etc/profile.d/lmod.sh
module --version
module purge
test "$MODULEPATH" = "$MODULEPATH_ROOT/Core"
test -z "$(find -L "$MODULEPATH_ROOT" -type l -print -quit)"
IFS=$'\t' read -r gnu_version openmpi_version < "$MODULEPATH_ROOT/gnu.toolchain"
gnu_major=${gnu_version%%.*}
openmpi_major=${openmpi_version%%.*}
module load "gfortran/$gnu_version"
test "$MODULEPATH" = "$MODULEPATH_ROOT/Compiler/gcc/$gnu_major:$MODULEPATH_ROOT/Core"
module load metis gidpost
test "$GRF_METISROOT" = /usr
test "$GRF_GIDPOSTROOT" = /usr/local
module load "openmpi/$openmpi_version" parmetis parpack mumps
test "$GRF_PARMETISROOT" = /usr
test "$GRF_PARPACKROOT" = /usr
test "$GRF_MUMPSROOT" = /usr
test "$MODULEPATH" = "$MODULEPATH_ROOT/MPI/gcc/$gnu_major/openmpi/$openmpi_major:$MODULEPATH_ROOT/Compiler/gcc/$gnu_major:$MODULEPATH_ROOT/Core"

# Compile and run OpenMP, MPI, and numerical-library links together.
cat > gnu.f90 <<'EOF'
program smoke
  use mpi
  use omp_lib
  implicit none
  integer :: ierr, ranks
  double precision :: x(2), y(2), ddot
  external ddot
  call MPI_Init(ierr)
  call MPI_Comm_size(MPI_COMM_WORLD, ranks, ierr)
  if (ranks /= 2) call MPI_Abort(MPI_COMM_WORLD, 1, ierr)
  if (omp_get_max_threads() < 1) call MPI_Abort(MPI_COMM_WORLD, 2, ierr)
  x = [1.0d0, 2.0d0]
  y = [3.0d0, 4.0d0]
  if (abs(ddot(2, x, 1, y, 1) - 11.0d0) > 1.0d-12) &
    call MPI_Abort(MPI_COMM_WORLD, 3, ierr)
  call MPI_Finalize(ierr)
end program
EOF
/usr/bin/mpifort.openmpi -fopenmp gnu.f90 -o gnu-smoke \
    -Wl,--no-as-needed -lparpack -larpack -ldmumps -lmumps_common -lpord \
    -lscalapack-openmpi -lparmetis -lmetis -lptscotch -lscotch -lopenblas
/usr/bin/mpirun.openmpi --oversubscribe -np 2 ./gnu-smoke

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
gcc gidpost.c -lgidpost -o gidpost-smoke
./gidpost-smoke
test -s smoke.post.res
test -s smoke.post.h5
gfortran -c /usr/local/share/gidpost/gidpost_interface.f90

# Exercise every installed compiler/MPI hierarchy and return to Core afterward.
module purge
test "$MODULEPATH" = "$MODULEPATH_ROOT/Core"
for profile_file in /usr/local/share/hofem/intel/*.toolchain; do
    [[ -f $profile_file ]] || continue
    profile=${profile_file##*/}
    profile=${profile%.toolchain}
    IFS=$'\t' read -r compiler mpi mkl < "$profile_file"
    module load "oneapi/compiler/$compiler"
    test "$MODULEPATH" = "$MODULEPATH_ROOT/Compiler/intel/${compiler%%.*}:$MODULEPATH_ROOT/Core"
    module load "impi/$mpi"
    test "$MODULEPATH" = "$MODULEPATH_ROOT/MPI/intel/${compiler%%.*}/impi/${mpi%%.*}:$MODULEPATH_ROOT/Compiler/intel/${compiler%%.*}:$MODULEPATH_ROOT/Core"
    icx --version | grep -F "${compiler}."
    ifx --version | grep -F "${compiler}."
    mpirun -V | grep -F "$mpi"
    test -f "${MKLROOT}/include/mkl.h"
    mpiifx -fiopenmp -qmkl gnu.f90 -o intel-smoke
    I_MPI_FABRICS=shm mpirun -np 2 ./intel-smoke
    test -e "$TBBROOT/lib/libtbb.so"
    test -e "$UMF_ROOT/lib/libumf.so"
    mpiicx -fiopenmp gidpost.c -lgidpost -o intel-gidpost-smoke
    ./intel-gidpost-smoke
    printf '#include <iostream>\n#include <oneapi/tbb/parallel_for.h>\nint main() { oneapi::tbb::parallel_for(0, 4, [](int){}); std::cout << "C++ works\\n"; }\n' > cpp.cpp
    icpx cpp.cpp -ltbb -o intel-cpp-smoke
    ./intel-cpp-smoke
    module purge
    test "$MODULEPATH" = "$MODULEPATH_ROOT/Core"
done
test "$(command -v mpifort)" = /usr/bin/mpifort

printf 'Development environment smoke tests passed.\n'
