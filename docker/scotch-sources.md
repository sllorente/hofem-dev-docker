# Scotch/PT-Scotch 7.0.10 build decisions

Source: the supplied `scotch-v7.0.10.tar.gz`. The build checks its SHA-256:

```text
8327725a08cdd4fc7575e291251883b4f93f75b07a54bc58f89f50dcbba7b244
```

`INSTALL.txt` documents the CMake build/test/install workflow and settings.
Sources are bundled locally; Flex, Bison, and compression development packages
are installed through Ubuntu APT.

## Configuration

| Setting | Choice |
| --- | --- |
| Graph integers (`INTSIZE`) | 32 bits, matching the existing graph-library ABI |
| Internal memory indices (`IDXSIZE`) | 64 bits, as recommended for 64-bit systems |
| `THREADS` | ON: pthread algorithms enabled |
| `MPI_THREAD_MULTIPLE` | ON: threaded MPI algorithms enabled and checked |
| Variants | Static and shared, both with explicit `-fPIC` |
| Build | Release; fixed random seed (`FIXED_SEED`, upstream default) |
| Components | Scotch, PT-Scotch, Fortran interfaces, EsMUMPS, upstream tools |
| METIS compatibility libraries/headers | Disabled; native METIS/ParMETIS are already installed |
| Compression | zlib, bzip2, and LZMA enabled |

This is pthread support, independent of OpenMP. The previous METIS/ParMETIS
OpenMP decisions remain unchanged. Each build uses `icx` and `ifx`, with the
matching Intel MPI wrappers supplied to CMake's MPI detection.

The upstream CMake file resets PIC to `BUILD_SHARED_LIBS`; it is adjusted to keep
PIC on for static libraries too. The upstream MPI thread probe is also adjusted
to compile with `-fPIC`. A build fails if the actual compiler definitions do not
include `SCOTCH_PTHREAD_MPI`, preventing silent fallback when MPI thread support
cannot be verified. No algorithm sources are patched.

## Required MPI initialization

C clients must include `<stdint.h>` and `<stdio.h>` before `<scotch.h>`, and `<mpi.h>` before
`<ptscotch.h>`.

PT-Scotch callers must request and check the MPI thread support level:

```c
int provided;
MPI_Init_thread(&argc, &argv, MPI_THREAD_MULTIPLE, &provided);
if (provided < MPI_THREAD_MULTIPLE) MPI_Abort(MPI_COMM_WORLD, 1);
```

Calling ordinary `MPI_Init` does not request this level. Tests use two Scotch
threads per MPI rank through `SCOTCH_PTHREAD_NUMBER=2`; this is not a fixed build
limit or image-wide default. With the variable unset, upstream selects available
cores. Set it according to the resources assigned to each MPI rank.

## Installation and modules

Intel builds install the complete upstream CMake package under
`/opt/intel-<compiler-major>/scotch/7.0.10`. The MPI hierarchy's
`/opt/intel-<compiler-major>/impi-<mpi-major>/ptscotch/7.0.10` is a symlink to that
installation. Sharing the prefix keeps upstream CMake exports valid and avoids
rebuilding or duplicating the serial libraries. The serial library itself does
not require MPI.

`scotch/7.0.10` modules use `Compiler/generic.lua`; `ptscotch/7.0.10` modules use
`MPI/generic.lua` and appear after loading the corresponding MPI module.
Settings and provenance are recorded in `share/scotch/build-config.json`.
Compilation databases, upstream instructions, and the license are also installed.

GNU reuses Ubuntu's Scotch/PT-Scotch **7.0.4**, including static/shared libraries,
without recompiling or changing distribution build settings. Its modules retain
the accurate version `7.0.4`. Package versions are recorded in
`/usr/local/share/hofem/scotch/gnu.packages`.

EsMUMPS is included for MUMPS integration. Upstream describes `libptesmumps` as a
dummy interface; its presence is not a claim of a separate parallel EsMUMPS solver.

## Validation

Each static/shared Intel build runs six focused upstream CTest cases covering
strategy parsing, graph ordering, and distributed graph checking (including
three MPI ranks). The installed-library tests cover:

- Serial and distributed partitioning, balance, and ordering permutations.
- Explicit two-thread context creation and two MPI ranks requesting
  `MPI_THREAD_MULTIPLE`.
- C and Fortran interfaces with both library variants.
- PIC flags in every compilation command and linking complete static archives
  into a shared library without text relocations.
- Correct Intel MPI library selection and recorded build settings.

Partitioning and ordering use separate strategy objects, as their strategy types
are distinct. Tests do not represent the full upstream test suite.
