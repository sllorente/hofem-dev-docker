#!/bin/bash
set -eo pipefail
source /etc/profile.d/lmod.sh
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cd "$test_dir"
source_file=/usr/local/share/hofem/tests/parmetis.c
check_stack() {
    local serial parallel
    module load metis/5.1.0 parmetis/4.0.3
    test "$GRF_PARMETIS_VERSION" = 4.0.3
    for variant in shared static; do
        serial=(-L "$GRF_METISLIB" -lmetis)
        parallel=(-L "$GRF_PARMETISLIB" -lparmetis)
        if [[ $variant == static ]]; then
            parallel=("$GRF_PARMETISLIB/libparmetis.a")
            if [[ $CC == icx ]]; then serial=("$GRF_METISLIB/libmetis.a"); fi
        fi
        "$MPICC" -fPIC -I "$GRF_PARMETISINC" -I "$GRF_METISINC" "$source_file" \
            "${parallel[@]}" "${serial[@]}" -lm -o parallel-check
        if [[ $CC == icx ]]; then
            I_MPI_FABRICS=shm mpirun -np 2 ./parallel-check
        else
            /usr/bin/mpirun.openmpi --oversubscribe -np 2 ./parallel-check
        fi
        if [[ $CC == icx && $variant == shared ]]; then
            ldd ./parallel-check | grep -F "$GRF_PARMETISLIB/libparmetis.so"
            ldd ./parallel-check | grep -F "$GRF_METISLIB/libmetis.so"
            ! ldd ./parallel-check | grep -E 'libmpi.so.40|lib(gomp|iomp)'
        fi
    done
    if [[ $CC == icx ]]; then
        "$MPICC" -fPIC -shared -Wl,--no-undefined -Wl,--whole-archive \
            "$GRF_PARMETISLIB/libparmetis.a" "$GRF_METISLIB/libmetis.a" \
            -Wl,--no-whole-archive -lm -o static-pic-check.so
        ! readelf -d static-pic-check.so | grep TEXTREL
        ! readelf -d "$GRF_PARMETISLIB/libparmetis.so" | grep TEXTREL
        python3 - "$GRF_PARMETISROOT" "$GRF_METISROOT" "$MPIROOT" <<'PY'
from pathlib import Path
import json
import sys
root = Path(sys.argv[1])
config = json.loads((root / 'share/parmetis/build-config.json').read_text())
assert config['index_bits'] == config['real_bits'] == 32
assert config['openmp'] is False and config['pic'] is True
assert config['metis_prefix'] == sys.argv[2] and config['mpi_root'] == sys.argv[3]
assert config['bundled_metis_rebuilt'] is False
for variant in ('static', 'shared'):
    commands = json.loads((root / f'share/parmetis/compile_commands-{variant}.json').read_text())
    assert commands and all('-fPIC' in c['command'] for c in commands)
    assert all('/libmetis/' not in c['file'] for c in commands)
print('Verified 32/32 ABI, OpenMP off, -fPIC, and reuse of the matching METIS')
PY
    fi
    echo "ParMETIS tests passed with $MPICC"
    module unload parmetis metis
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
