# MUMPS 5.7.3 build decisions

Source: the supplied `MUMPS_5.7.3.tar.gz`, used locally without downloading sources.
The installer verifies SHA-256:

```text
84a47f7c4231b9efdf4d4f631a2cae2bdd9adeaabc088261d15af040143ed112
```

The build follows `INSTALL`, `Make.inc/Makefile.inc.generic`, and
`Make.inc/Makefile.INTEL.PAR`. It generates a stack-specific `Makefile.inc`.

## Configuration

| Setting | Choice |
| --- | --- |
| Execution | MPI and OpenMP; the MPI library also supports one-rank runs |
| Arithmetic | Single/double real and single/double complex (`s`, `d`, `c`, `z`) |
| Libraries | Static and shared; every C/Fortran object uses `-fPIC` |
| Optimization | `-O2`, without processor-specific instruction requirements |
| Integer ABI | Default 32-bit integers, LP64 BLAS/ScaLAPACK; MUMPS retains its native 64-bit nonzero counts |
| Orderings | PORD, METIS, ParMETIS, Scotch, PT-Scotch |
| Numerical backend | Matching oneMKL LP64, Intel OpenMP threading, Intel-MPI BLACS and ScaLAPACK |
| Additional definitions | `GEMMT_AVAILABLE`, `DETERMINISTIC_PARALLEL_GRAPH` |
| Scotch OpenMP thread import | Disabled; Scotch manages its own pthreads |

Before compiling, the installer loads the compiler, MPI, `metis`, `parmetis`,
`scotch`, `ptscotch`, and `mumps` modules. Paths come from their `GRF_*` variables.
Intel builds use `mpiicx`/`mpiifx` and the same ordering libraries as the loaded
compiler/MPI stack. `-Dparmetis` and `-Dptscotch` also enable their serial interfaces,
as documented upstream. METIS/Scotch are not rebuilt. Both EsMUMPS interfaces are
linked. C compilation explicitly includes `stdint.h` for Scotch's public types.

The base contains only oneMKL core packages. The derived image adds
`intel-oneapi-mkl-cluster-devel-<series>` and its runtime package, pinned to the
installed core package version. These provide ScaLAPACK/BLACS without installing
complete oneAPI or oneMKL metapackages. Exact versions are recorded under
`/usr/local/share/hofem/mumps/`.

Upstream static targets run first, with PIC flags already enabled; shared targets
reuse those PIC objects. Arithmetics build in sequence to avoid competing recursive
archive updates. Static MUMPS linking can still use shared dependency libraries;
this does not imply a completely static executable.

## Installation and runtime

Intel modules are generic MPI-hierarchy symlinks named `mumps/5.7.3`. Prefixes are
`/opt/intel-<major>/impi-<mpi-major>/mumps/5.7.3`, including all six static/shared
libraries, public headers, compiler-specific Fortran modules, upstream examples,
the license, `Makefile.inc`, and `share/mumps/build-config.json`.

GNU reuses Ubuntu's **MUMPS 5.6.2** static/shared libraries through `mumps/5.6.2`.
That package has PORD ordering but lacks METIS/ParMETIS/Scotch/PT-Scotch backends;
loading those modules does not add backends to an already compiled library.
Distribution compilation settings are preserved.

Applications must initialize MPI with `MPI_Init_thread` and check for
`MPI_THREAD_MULTIPLE` when using the threaded PT-Scotch backend. Set
`OMP_NUM_THREADS`, `MKL_NUM_THREADS`, and `SCOTCH_PTHREAD_NUMBER` according to
resources per MPI rank. Tests set each to two; these are not image-wide defaults.
Use `share/mumps/Makefile.inc` as the installed linking example. Keep headers,
Fortran modules, MPI wrappers, and libraries from the same stack.

## Validation

Installed tests solve a tridiagonal system with a known solution, on two MPI ranks,
for all four arithmetic types with both static and shared MUMPS libraries. Intel
tests explicitly select each of the five ordering backends and check `INFOG(7)`
and `INFOG(32)` to detect fallback. GNU tests select its available PORD backend.
Double-precision Fortran clients exercise both library variants. Whole-archive
linking of all Intel static archives into one shared object checks PIC and missing
symbols, and dynamic dependency checks reject accidental OpenMPI linking.
These checks are targeted validation, not a full upstream test suite.
