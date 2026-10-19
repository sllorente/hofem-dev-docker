#!/bin/bash
set -eo pipefail
source /etc/profile.d/lmod.sh
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cd "$test_dir"
export OMP_NUM_THREADS=2 MKL_NUM_THREADS=2 SCOTCH_PTHREAD_NUMBER=2
export I_MPI_FABRICS=shm I_MPI_PIN=0
if [[ $(id -u) == 0 ]]; then
    export OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
fi
check_stack() {
    module load metis parmetis scotch ptscotch mumps
    local variant arithmetic number flags modes
    local -a runner orderings numerical mumps linkflags
    modes=5
    if [[ $CC == icx ]]; then
        flags=-qopenmp
        linkflags=(-nofor_main)
        runner=(mpirun -np 2)
        numerical=(-L "$MKLROOT/lib" -lmkl_scalapack_lp64 -lmkl_blacs_intelmpi_lp64
                   -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core)
    else
        flags=-fopenmp
        linkflags=()
        runner=(/usr/bin/mpirun.openmpi --oversubscribe -np 2)
        numerical=(-lscalapack-openmpi -llapack -lblas)
        # Ubuntu's existing package enables PORD but no external ordering backends.
        modes=-1
    fi
    orderings=(-L "$GRF_PARMETISLIB" -lparmetis -L "$GRF_METISLIB" -lmetis
               -L "$GRF_PTSCOTCHLIB" -lptesmumps -lptscotch -lptscotcherr
               -L "$GRF_SCOTCHLIB" -lesmumps -lscotch -lscotcherr)
    for variant in shared static; do
        number=0
        for arithmetic in s d c z; do
            number=$((number+1))
            mumps=(-L "$GRF_MUMPSLIB" -l"${arithmetic}mumps" -lmumps_common -lpord)
            if [[ $variant == static ]]; then
                mumps=("$GRF_MUMPSLIB/lib${arithmetic}mumps.a" "$GRF_MUMPSLIB/libmumps_common.a" "$GRF_MUMPSLIB/libpord.a")
            fi
            "$MPICC" -fPIC "$flags" -DARITH="$number" -I "$GRF_MUMPSINC" \
                -c /usr/local/share/hofem/tests/mumps.c -o check.o
            "$MPIFC" -fPIC "$flags" "${linkflags[@]}" check.o "${mumps[@]}" "${orderings[@]}" \
                "${numerical[@]}" -lz -lbz2 -llzma -lpthread -lm -ldl -o check
            "${runner[@]}" ./check "$modes"
            if [[ $arithmetic == d ]]; then
                "$MPIFC" -fPIC "$flags" -I "$GRF_MUMPSINC" /usr/local/share/hofem/tests/mumps.f90 \
                    "${mumps[@]}" "${orderings[@]}" "${numerical[@]}" \
                    -lz -lbz2 -llzma -lpthread -lm -ldl -o fortran-check
                "${runner[@]}" ./fortran-check
            fi
            if [[ $CC == icx ]]; then
                ldd ./check | grep -F "$MPIROOT/" | grep 'libmpi.so'
                ! ldd ./check | grep libmpi.so.40
            fi
        done
    done
    if [[ $CC == icx ]]; then
        "$MPIFC" -fPIC "$flags" -shared -Wl,--no-undefined -Wl,--whole-archive \
            "$GRF_MUMPSLIB/"lib{smumps,dmumps,cmumps,zmumps,mumps_common,pord}.a \
            -Wl,--no-whole-archive "${orderings[@]}" "${numerical[@]}" \
            -lz -lbz2 -llzma -lpthread -lm -ldl -o all-static-pic.so
        ! readelf -d all-static-pic.so | grep TEXTREL
        python3 - "$GRF_MUMPSROOT" <<'PY'
from pathlib import Path
import json, os, sys
root = Path(sys.argv[1])/'share/mumps'
config = json.loads((root/'build-config.json').read_text())
assert config['version'] == '5.7.3' and config['integer_bits'] == 32
assert all(config[k] for k in ('mpi','openmp','mkl_threaded','pic','static','shared'))
assert config['mpi_root'] == os.environ['MPIROOT']
assert config['mkl_root'] == os.environ['MKLROOT']
for name, prefix in config['orderings'].items():
    assert prefix == os.environ['GRF_'+name.upper()+'ROOT']
settings = (root/'Makefile.inc').read_text().splitlines()
for name in ('OPTC','OPTF','OPTL'):
    assert any(line.startswith(name+' = ') and '-fPIC' in line and '-qopenmp' in line for line in settings)
print('Verified MUMPS PIC/OpenMP settings and matching ordering/MPI/MKL prefixes')
PY
    fi
    echo "MUMPS tests passed with $MPIFC ($GRF_MUMPS_VERSION)"
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
