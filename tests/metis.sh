#!/bin/bash
set -eo pipefail
source /etc/profile.d/lmod.sh
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cd "$test_dir"
source_file=/usr/local/share/hofem/tests/metis.c
check_stack() {
    module load metis/5.1.0
    test "$GRF_METIS_VERSION" = 5.1.0
    "$CC" -fPIC -I "$GRF_METISINC" "$source_file" -L "$GRF_METISLIB" -lmetis -lm -o shared-check
    ./shared-check
    if [[ $CC == icx ]]; then
        ldd ./shared-check | grep -F "$GRF_METISLIB/libmetis.so"
        ! ldd ./shared-check | grep -E 'lib(gomp|iomp)'
        "$CC" -fPIC -I "$GRF_METISINC" "$source_file" "$GRF_METISLIB/libmetis.a" -lm -o static-check
        ./static-check
        "$CC" -fPIC -shared -Wl,--no-undefined -Wl,--whole-archive "$GRF_METISLIB/libmetis.a" \
            -Wl,--no-whole-archive -lm -o static-pic-check.so
        ! readelf -d static-pic-check.so | grep TEXTREL
        ! readelf -d "$GRF_METISLIB/libmetis.so" | grep TEXTREL
        "$GRF_METISBIN/gpmetis" -help > gpmetis-help.txt
        test -s gpmetis-help.txt
        python3 - "$GRF_METISROOT" <<'PY'
from pathlib import Path
import json
import sys
root = Path(sys.argv[1])
config = json.loads((root / 'share/metis/build-config.json').read_text())
assert config['index_bits'] == config['real_bits'] == 32
assert config['openmp'] is False and config['pic'] is True
for variant in ('static', 'shared'):
    commands = json.loads((root / f'share/metis/compile_commands-{variant}.json').read_text())
    assert commands and all('-fPIC' in c['command'] for c in commands)
print('Verified 32/32 ABI, OpenMP disabled, and -fPIC on every static/shared compile command')
PY
    else
        echo 'Reused GNU system METIS; no static archive is supplied by the Ubuntu package'
    fi
    echo "METIS tests passed with $CC"
    module unload metis
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
