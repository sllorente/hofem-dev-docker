#!/bin/bash
set -eo pipefail
source /etc/profile.d/lmod.sh
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cd "$test_dir"
export SCOTCH_PTHREAD_NUMBER=2 I_MPI_FABRICS=shm I_MPI_PIN=0
source_file=/usr/local/share/hofem/tests/scotch.c
check_stack() {
    local serial parallel required cpp
    module load scotch ptscotch
    cpp=(-cpp)
    [[ $FC != ifx ]] || cpp=(-fpp)
    required=(-DREQUIRE_THREADS)
    for variant in shared static; do
        serial=(-L "$GRF_SCOTCHLIB" -lscotch -lscotcherr)
        parallel=(-L "$GRF_PTSCOTCHLIB" -lptscotch -lptscotcherr)
        if [[ $variant == static ]]; then
            serial=("$GRF_SCOTCHLIB/libscotch.a" "$GRF_SCOTCHLIB/libscotcherr.a")
            parallel=("$GRF_PTSCOTCHLIB/libptscotch.a" "$GRF_PTSCOTCHLIB/libptscotcherr.a")
        fi
        "$CC" -fPIC "${required[@]}" -I "$GRF_SCOTCHINC" "$source_file" "${serial[@]}" \
            -lz -lbz2 -llzma -pthread -lm -o serial-check
        ./serial-check
        "$MPICC" -fPIC "${required[@]}" -DUSE_PTSCOTCH -I "$GRF_PTSCOTCHINC" "$source_file" \
            "${parallel[@]}" "${serial[@]}" -lz -lbz2 -llzma -pthread -lm -o parallel-check
        if [[ $CC == icx ]]; then mpirun -np 2 ./parallel-check;
        else /usr/bin/mpirun.openmpi --oversubscribe -np 2 ./parallel-check; fi
        "$FC" -fPIC "${cpp[@]}" -I "$GRF_SCOTCHINC" /usr/local/share/hofem/tests/scotch.f90 \
            "${serial[@]}" -lz -lbz2 -llzma -pthread -lm -o fortran-serial-check
        ./fortran-serial-check
        "$MPIFC" -fPIC "${cpp[@]}" -DUSE_PTSCOTCH -I "$GRF_PTSCOTCHINC" \
            /usr/local/share/hofem/tests/scotch.f90 "${parallel[@]}" "${serial[@]}" \
            -lz -lbz2 -llzma -pthread -lm -o fortran-parallel-check
        if [[ $CC == icx ]]; then mpirun -np 2 ./fortran-parallel-check;
        else /usr/bin/mpirun.openmpi --oversubscribe -np 2 ./fortran-parallel-check; fi
        if [[ $CC == icx && $variant == shared ]]; then
            ldd ./parallel-check | grep -F "$GRF_PTSCOTCHLIB/libptscotch.so"
            ! ldd ./parallel-check | grep libmpi.so.40
        fi
    done
    if [[ $CC == icx ]]; then
        "$MPICC" -fPIC -shared -Wl,--no-undefined -Wl,--whole-archive \
            "$GRF_PTSCOTCHLIB/libptscotch.a" "$GRF_SCOTCHLIB/libscotch.a" \
            -Wl,--no-whole-archive "$GRF_PTSCOTCHLIB/libptscotcherr.a" \
            -lz -lbz2 -llzma -pthread -lm -o static-pic-check.so
        ! readelf -d static-pic-check.so | grep TEXTREL
        python3 - "$GRF_SCOTCHROOT" "$MPIROOT" <<'PY'
from pathlib import Path
import json
import sys
root = Path(sys.argv[1])
config = json.loads((root/'share/scotch/build-config.json').read_text())
assert config['threads'] and config['mpi_thread_multiple'] and config['pic']
assert config['graph_integer_bits']==32 and config['internal_index_bits']==64
assert config['mpi_root']==sys.argv[2]
for variant in ('static','shared'):
    commands=json.loads((root/f'share/scotch/compile_commands-{variant}.json').read_text())
    assert commands and all('-fPIC' in c['command'] for c in commands)
    assert any('-DSCOTCH_PTHREAD_MPI' in c['command'] for c in commands)
    assert any('-DIDXSIZE64' in c['command'] for c in commands)
print('Verified pthreads, threaded MPI, 32/64 integer layout, and PIC in both variants')
PY
    fi
    echo "Scotch/PT-Scotch tests passed with $CC and $MPICC"
    module unload ptscotch scotch
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
