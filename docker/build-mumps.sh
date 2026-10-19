#!/bin/bash
set -eo pipefail
prefix=${1:?Specify the MUMPS installation prefix}
: "${MPICC:?Load Intel MPI}"
: "${MPIFC:?Load Intel MPI}"
for dependency in METIS PARMETIS SCOTCH PTSCOTCH; do
    variable=GRF_${dependency}ROOT
    test -d "${!variable:?Load the ordering modules}"
done
archive=${MUMPS_ARCHIVE:-/usr/local/share/hofem/sources/MUMPS_5.7.3.tar.gz}
sha256=84a47f7c4231b9efdf4d4f631a2cae2bdd9adeaabc088261d15af040143ed112
printf '%s  %s\n' "$sha256" "$archive" | sha256sum -c -
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
tar -xzf "$archive" -C "$build_dir"
src=$build_dir/MUMPS_5.7.3
test -f "$MKLROOT/lib/libmkl_scalapack_lp64.so"
test -f "$MKLROOT/lib/libmkl_blacs_intelmpi_lp64.so"
python3 - "$src" "$prefix" <<'PY'
import os
from pathlib import Path
import sys
src, prefix = map(Path, sys.argv[1:])
e = os.environ
values = dict(
    ORDERINGSF='-Dpord -Dparmetis -Dptscotch',
    ORDERINGSC='$(ORDERINGSF)',
    LPORDDIR='$(topdir)/PORD/lib', IPORD='-I$(topdir)/PORD/include',
    LPORD='-L$(LPORDDIR) -lpord',
    IMETIS=f'-I{e["GRF_METISINC"]} -I{e["GRF_PARMETISINC"]}',
    LMETIS=f'-L{e["GRF_PARMETISLIB"]} -lparmetis -L{e["GRF_METISLIB"]} -lmetis',
    ISCOTCH=f'-I{e["GRF_SCOTCHINC"]} -I{e["GRF_PTSCOTCHINC"]}',
    LSCOTCH=f'-L{e["GRF_PTSCOTCHLIB"]} -lptesmumps -lptscotch -lptscotcherr '
            f'-L{e["GRF_SCOTCHLIB"]} -lesmumps -lscotch -lscotcherr',
    LORDERINGS='$(LMETIS) $(LPORD) $(LSCOTCH)',
    IORDERINGSF='$(ISCOTCH)', IORDERINGSC='$(IMETIS) $(IPORD) $(ISCOTCH)',
    PLAT='', LIBEXT='.a', LIBEXT_SHARED='.so', SONAME='-soname',
    SHARED_OPT='-shared -Wl,--no-undefined', FPIC_OPT='-fPIC',
    OUTC='-o ', OUTF='-o ', RM='/bin/rm -f',
    CC=e['MPICC'], FC=e['MPIFC'], FL=e['MPIFC'], AR='ar rcs ', RANLIB='ranlib',
    LAPACK=f'-L{e["MKLROOT"]}/lib -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core',
    SCALAP=f'-L{e["MKLROOT"]}/lib -lmkl_scalapack_lp64 -lmkl_blacs_intelmpi_lp64',
    INCPAR='', LIBPAR='$(SCALAP) $(LAPACK)', LIBBLAS='$(LAPACK)',
    LIBOTHERS='-lz -lbz2 -llzma -lpthread -lm -ldl', CDEFS='-DAdd_',
    OPTF='-O2 -fPIC -qopenmp -DGEMMT_AVAILABLE -DDETERMINISTIC_PARALLEL_GRAPH',
    OPTC='-O2 -fPIC -qopenmp -include stdint.h -DDETERMINISTIC_PARALLEL_GRAPH',
    OPTL='-O2 -fPIC -qopenmp -nofor_main',
    INCS='$(INCPAR)', LIBS='$(LIBPAR)', LIBSEQNEEDED='',
)
paths = [str(prefix/'lib'), e['GRF_METISLIB'], e['GRF_PARMETISLIB'],
         e['GRF_SCOTCHLIB'], e['GRF_PTSCOTCHLIB'], e['MKLROOT']+'/lib']
values['RPATH_OPT'] = ' '.join('-Wl,-rpath,'+p for p in dict.fromkeys(paths))
(src/'Makefile.inc').write_text(''.join(f'{k} = {v}\n' for k,v in values.items()))
PY
# All objects are PIC from the start; shared targets can safely reuse them.
# Build each arithmetic in turn to avoid concurrent recursive archive updates.
make -C "$src" -j1 prerequisites
for arithmetic in s d c z; do
    make -C "$src/src" -j "${BUILD_JOBS:-2}" "$arithmetic"
done
make -C "$src" -j1 prerequisitesshared
for arithmetic in s d c z; do
    make -C "$src/src" -j "${BUILD_JOBS:-2}" "${arithmetic}shared"
done
install -d "$prefix/lib" "$prefix/include" "$prefix/share/mumps"
install -m 644 "$src/lib/"*.a "$src/lib/"*.so "$prefix/lib/"
install -m 644 "$src/include/"*.h "$src/src/"*.mod "$prefix/include/"
install -m 644 "$src/Makefile.inc" "$src/INSTALL" "$src/README" "$src/LICENSE" "$prefix/share/mumps/"
install -m 644 "$src/doc/"CeCILL-C*.txt "$src/doc/userguide_5.7.3.pdf" "$prefix/share/mumps/"
install -m 644 "$src/PORD/README" "$prefix/share/mumps/PORD-README"
cp -r "$src/examples" "$prefix/share/mumps/"
python3 - "$prefix" "$sha256" <<'PY'
from pathlib import Path
import json, os, sys
e = os.environ
config = dict(version='5.7.3', arithmetic=['s','d','c','z'], mpi=True,
              openmp=True, mkl_threaded=True, integer_bits=32, pic=True,
              static=True, shared=True, gemmt=True, deterministic_parallel_graph=True,
              scotch_import_omp_threads=False, archive_sha256=sys.argv[2],
              mpi_root=e['MPIROOT'], mkl_root=e['MKLROOT'],
              orderings={p.lower():e['GRF_'+p+'ROOT'] for p in ('METIS','PARMETIS','SCOTCH','PTSCOTCH')})
(Path(sys.argv[1])/'share/mumps/build-config.json').write_text(json.dumps(config,indent=2)+'\n')
PY
