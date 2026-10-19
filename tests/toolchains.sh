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
test -z "$(find "$MODULEPATH_ROOT" -name .modulerc.lua -print -quit)"
if [[ ${1:-} != --with-libraries ]]; then
    test -z "$(find /opt /usr/local -type f -name 'libgidpost*' -print -quit)"
    for tree in "$MODULEPATH_ROOT" /usr/local/share/hofem/modulefiles; do
        while IFS= read -r alias; do
            test "$(basename "$(readlink -f "$alias")")" != generic.lua
        done < <(find "$tree" -type l -name '*.lua')
    done
fi
IFS=$'\t' read -r gnu_version openmpi_version < "$MODULEPATH_ROOT/gnu.toolchain"
gnu_major=${gnu_version%%.*}
openmpi_major=${openmpi_version%%.*}
module load "gfortran/$gnu_version"
test "$MODULEPATH" = "$MODULEPATH_ROOT/Compiler/gcc/$gnu_major:$MODULEPATH_ROOT/Core"
module load "openmpi/$openmpi_version"
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
"$MPIFC" -fPIC -fopenmp gnu.f90 -o gnu-smoke \
    -Wl,--no-as-needed -lparpack -larpack -ldmumps -lmumps_common -lpord \
    -lscalapack-openmpi -lparmetis -lmetis -lptscotch -lscotch -lopenblas
/usr/bin/mpirun.openmpi --oversubscribe -np 2 ./gnu-smoke

# Exercise every installed compiler/MPI hierarchy and return to Core afterward.
module purge
test "$MODULEPATH" = "$MODULEPATH_ROOT/Core"
for profile_file in /usr/local/share/hofem/intel/*.toolchain; do
    [[ -f $profile_file ]] || continue
    profile=${profile_file##*/}
    profile=${profile%.toolchain}
    IFS=$'\t' read -r compiler mpi mkl < "$profile_file"
    module load "oneapi/compiler/$compiler"
    test "$CC" = icx
    test "$CXX" = icpx
    test "$FC" = ifx
    test "$F77" = ifx
    test "$MODULEPATH" = "$MODULEPATH_ROOT/Compiler/intel/${compiler%%.*}:$MODULEPATH_ROOT/Core"
    module load "impi/$mpi"
    test "$MPICC" = mpiicx
    test "$MPICXX" = mpiicpx
    test "$MPIFC" = mpiifx
    test "$MPIROOT" = "$I_MPI_ROOT"
    test "$GRF_IMPIROOT" = "$MPIROOT"
    test "$GRF_MKLROOT" = "$MKLROOT"
    test "$GRF_TBBROOT" = "$TBBROOT"
    test "$GRF_UMFROOT" = "$UMF_ROOT"
    test "$MODULEPATH" = "$MODULEPATH_ROOT/MPI/intel/${compiler%%.*}/impi/${mpi%%.*}:$MODULEPATH_ROOT/Compiler/intel/${compiler%%.*}:$MODULEPATH_ROOT/Core"
    icx --version | grep -F "${compiler}."
    ifx --version | grep -F "${compiler}."
    mpirun -V | grep -F "$mpi"
    test -f "${MKLROOT}/include/mkl.h"
    "$MPIFC" -fPIC -fiopenmp -qmkl gnu.f90 -o intel-smoke
    I_MPI_FABRICS=shm mpirun -np 2 ./intel-smoke
    test -e "$TBBROOT/lib/libtbb.so"
    test -e "$UMF_ROOT/lib/libumf.so"
    printf '#include <iostream>\n#include <oneapi/tbb/parallel_for.h>\nint main() { oneapi::tbb::parallel_for(0, 4, [](int){}); std::cout << "C++ works\\n"; }\n' > cpp.cpp
    "$MPICXX" -fPIC cpp.cpp -ltbb -o intel-cpp-smoke
    ./intel-cpp-smoke
    module purge
    test "$MODULEPATH" = "$MODULEPATH_ROOT/Core"
done
test "$(command -v mpifort)" = /usr/bin/mpifort

printf 'GREMA toolchain smoke tests passed.\n'
