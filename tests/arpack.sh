#!/bin/bash
set -eo pipefail
source /etc/profile.d/lmod.sh
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cd "$test_dir"
source_file=/usr/local/share/hofem/tests/arpack.f90

check_stack() {
    local cpp blas serial parallel library prefix precision symbol
    cpp=(-cpp)
    blas=(-llapack -lblas)
    if [[ $FC == ifx ]]; then cpp=(-fpp); blas=(-qmkl=sequential); fi
    module load arpack/97 parpack/97
    test "$GRF_ARPACK_VERSION" = 97
    test "$GRF_PARPACK_VERSION" = 97
    test -s "$GRF_ARPACKINC/debug.h"
    test -s "$GRF_PARPACKINC/debug.h"
    for variant in shared static; do
        serial=(-L "$GRF_ARPACKLIB" -larpack)
        parallel=(-L "$GRF_PARPACKLIB" -lparpack "${serial[@]}")
        if [[ $variant == static ]]; then
            serial=("$GRF_ARPACKLIB/libarpack.a")
            parallel=("$GRF_PARPACKLIB/libparpack.a" "${serial[@]}")
        fi
        "$FC" -fPIC "${cpp[@]}" "$source_file" "${serial[@]}" "${blas[@]}" -o serial-check
        ./serial-check
        "$MPIFC" -fPIC "${cpp[@]}" -DUSE_PARPACK "$source_file" "${parallel[@]}" "${blas[@]}" -o parallel-check
        if [[ $FC == ifx ]]; then
            I_MPI_FABRICS=shm mpirun -np 2 ./parallel-check
        else
            /usr/bin/mpirun.openmpi --oversubscribe -np 2 ./parallel-check
        fi
        if [[ $variant == shared && $FC == ifx ]]; then
            ldd ./serial-check | grep -F "$GRF_ARPACKLIB/libarpack.so"
            ldd ./parallel-check | grep -F "$GRF_PARPACKLIB/libparpack.so"
            ! ldd ./parallel-check | grep -F libmpi.so.40
        fi
    done
    for library in arpack parpack; do
        prefix=$GRF_ARPACKLIB
        [[ $library != parpack ]] || prefix=$GRF_PARPACKLIB
        for precision in s d c z; do
            symbol=${precision}naupd_
            [[ $library != parpack ]] || symbol=p$symbol
            nm -g --defined-only "$prefix/lib$library.a" \
                | awk '{print $NF}' | grep -x "$symbol"
        done
    done
    if [[ $FC == ifx ]]; then
        ! readelf -d "$GRF_ARPACKLIB/libarpack.so" | grep TEXTREL
        ! readelf -d "$GRF_PARPACKLIB/libparpack.so" | grep TEXTREL
    fi
    echo "ARPACK/PARPACK tests passed with $FC and $MPIFC"
}
module purge
module load gfortran openmpi
check_stack
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    module purge
    module load "oneapi/compiler/$compiler" "impi/$mpi"
    check_stack
done
module purge
