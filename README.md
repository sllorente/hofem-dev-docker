# GREMA and HOFEM development images

This repository provides Ubuntu 24.04 LTS environments for developing HOFEM,
GREMA's electromagnetic solver using High Order Finite Elements. HOFEM application
sources are maintained separately and can be shared with a container through a
bind mount.

## Images

| Image | Dockerfile | Contents |
| --- | --- | --- |
| `grema-dev` | `Dockerfile` | Development tools, Lmod, GNU/OpenMPI, two Intel compiler/MPI pairs, and Ubuntu numerical libraries. |
| `hofem-dev` | `Dockerfile.hofem` | Everything in `grema-dev`, plus HOFEM numerical libraries and compiler/MPI-specific modules described below. |

`hofem-dev` uses `grema-dev:latest` as its base. Adding libraries to `hofem-dev`
does not reinstall the compilers or MPI libraries.

## Usage

### Build the images

Run these commands from the parent directory of `hofem-dev-docker/`.

First, build the complete toolchain image:

```bash
docker build --platform linux/amd64 -t grema-dev hofem-dev-docker/
```

Then, build the HOFEM library image using that base:

```bash
docker build --platform linux/amd64 -f hofem-dev-docker/Dockerfile.hofem -t hofem-dev hofem-dev-docker/
```

The final argument, `hofem-dev-docker/`, is the build context: the directory
containing the Dockerfiles, scripts, modulefiles, and bundled sources. Adjust this
path if your repository is stored elsewhere. The `-f` option selects the Dockerfile;
`-t` gives the image its name.

The complete images require `linux/amd64` for Intel tools. Building `grema-dev`
installs several GB of packages. Once it exists, rebuild only `hofem-dev` when
adding libraries; rebuild `grema-dev` when changing the toolchains.

### Run a container

Start an interactive HOFEM environment and share a host directory:

```bash
docker run --rm -it -v "/absolute/path/to/directory:/workspace" hofem-dev
```

- `--rm` removes the container when you exit.
- `-it` provides an interactive terminal.
- `-v HOST_DIRECTORY:CONTAINER_DIRECTORY` makes a host directory accessible inside
  the container.

The shell opens in `/workspace`. Files in the shared directory remain on the host
after the container exits. Changes elsewhere in the container are discarded when
it is removed.

For example:

```bash
docker run --rm -it -v "$PWD:/workspace" hofem-dev
```

The current directory where you launch Docker becomes `/workspace` inside the
container. If you launch it from `/home/user/hofem`, that directory appears as
`/workspace` in the container.

Use `grema-dev` instead of `hofem-dev` to run the toolchain environment without
aditional libraries compiled.

## Select a compiler and MPI stack

Lmod is initialized when the container starts. No modules are loaded automatically;
`module avail` initially shows only the `Core` modules. System GCC, GFortran, and
OpenMPI are also available without loading modules.

### GNU and OpenMPI

```bash
module purge
module load gfortran
module load openmpi
```

### Intel 2025.3 and Intel MPI 2021.17

```bash
module purge
module load oneapi/compiler/2025.3
module load impi/2021.17
```

### Newest installed Intel stack

```bash
module purge
module load oneapi/compiler
module load impi
```

The base build installs the newest available Intel series alongside the 2025.3
compiler and MPI 2021.17 pair. The tested images contain compiler 2026.2.0 and MPI
2021.19.0 as the newer pair. Fresh builds resolve the latest series from Intel's
signed APT metadata.

The Intel compiler module sets `CC=icx`, `CXX=icpx`, `FC=ifx`, and `F77=ifx`.
The MPI module sets `MPICC=mpiicx`, `MPICXX=mpiicpx`, `MPIFC=mpiifx`, and `MPIROOT`.
Compiler modules also load TBB and UMF, plus MKL and the debugger when available.

Use `module purge` before changing the complete stack. When using `docker exec`,
start Bash with `bash -lc` to initialize Lmod.

## Use GiDPost

In `hofem-dev`, select a compiler stack first, then load a GiDPost version:

```bash
module load gidpost/2.14
```

To switch versions while keeping the compiler stack:

```bash
module swap gidpost/2.14 gidpost/2.9
```

Each module selects the library compiled with the active compiler. It defines:

```text
GRF_GIDPOSTROOT       installation prefix
GRF_GIDPOSTINC        headers and Fortran module directory
GRF_GIDPOSTLIB        library directory
GRF_GIDPOSTBIN        executable directory, if provided
GRF_GIDPOST_VERSION   selected version
```

For example, compile a Fortran program with:

```bash
"$FC" -fPIC -I "$GRF_GIDPOSTINC" program.f90 \
    -L "$GRF_GIDPOSTLIB" -lgidpost_fortran -lgidpost
```

Both releases provide static and shared C and Fortran libraries, plus a
compiler-specific `gidpost.mod`. Static linking additionally requires HDF5 and
its high-level library, zlib, threads, and the math library.

Installations use `/opt/gcc-<major>/gidpost/<version>` and
`/opt/intel-<major>/gidpost/<version>`. Existing GNU installations of the requested
version are reused. All source-built code uses `-fPIC`; CMake builds also enable
`CMAKE_POSITION_INDEPENDENT_CODE`.

## Use ARPACK and PARPACK

After selecting a compiler and MPI stack, load:

```bash
module load arpack/97
module load parpack/97
```

ARPACK provides serial eigenvalue solvers; PARPACK provides their MPI equivalents
and requires both libraries when linking. ARPACK modules appear after loading the
compiler; PARPACK modules appear after loading MPI. The modules set `GRF_ARPACK*`
and `GRF_PARPACK*` installation paths and version variables.

The supplied archive is treated as release **97**. Both Intel stacks compile its
single, double, complex, and double-complex routines into `libarpack.a`,
`libarpack.so`, `libparpack.a`, and `libparpack.so`, using `-fPIC`, sequential LP64
MKL, and the matching Intel MPI. Prefixes are:

```text
/opt/intel-<compiler-major>/arpack/97
/opt/intel-<compiler-major>/impi-<mpi-major>/parpack/97
```

GNU reuses Ubuntu's installed ARPACK/PARPACK libraries instead of rebuilding them.
For GNU, the `/97` modules are compatibility aliases for those system libraries,
not source builds of the supplied archive. The tested package version is 3.9.1;
exact package versions are recorded in `/usr/local/share/hofem/arpack/gnu.packages`.

See [ARPACK build details](docker/arpack-sources.md) for the archive checksum,
README instructions, and compatibility changes.

## Use METIS

After selecting a compiler, load the serial graph-partitioning library:

```bash
module load metis/5.1.0
```

The module sets `GRF_METISROOT`, `GRF_METISINC`, `GRF_METISLIB`, `GRF_METISBIN`,
and `GRF_METIS_VERSION`. METIS does not require MPI.

The approved Intel build settings are:

| Setting | Choice |
| --- | --- |
| Graph index type (`idx_t`) | 32 bits |
| Real type (`real_t`) | 32 bits |
| OpenMP | Disabled |
| Build | Optimized Release; debugging, assertions, and profiling disabled |
| Libraries | Static and shared, both compiled with `-fPIC` |

The data types and OpenMP setting retain upstream defaults; the type widths also
match GNU's installed METIS. Callers must use the matching types from `metis.h`.
Both Intel stacks build from `docker/metis-5.1.0.tar.gz` and install under
`/opt/intel-<compiler-major>/metis/5.1.0`, including tools such as `gpmetis`.
GNU reuses Ubuntu's METIS 5.1.0 shared library. Its package does not supply a
static archive, and it is not rebuilt under the GNU reuse rule.

Each Intel installation records its settings in `share/metis/build-config.json`.
See [METIS build decisions](docker/metis-sources.md) for the archive checksum,
full configuration, GNU exception, and validation details.

## Use ParMETIS

ParMETIS provides MPI graph partitioning and ordering. Select a compiler and its
MPI implementation, then load:

```bash
module load metis/5.1.0
module load parmetis/4.0.3
```

The ParMETIS module appears in the MPI hierarchy and defines `GRF_PARMETISROOT`,
`GRF_PARMETISINC`, `GRF_PARMETISLIB`, `GRF_PARMETISBIN`, and
`GRF_PARMETIS_VERSION`. Intel installations use
`/opt/intel-<compiler-major>/impi-<mpi-major>/parmetis/4.0.3`.

Both Intel stacks provide static and shared libraries compiled with `-fPIC`,
32-bit indices and reals, and OpenMP disabled, matching METIS. Builds use the
matching Intel MPI wrappers and link the existing METIS 5.1.0; the bundled METIS
copy is not rebuilt. Static consumers must link both libraries and MPI.

GNU reuses Ubuntu's ParMETIS 4.0.3/OpenMPI libraries. Those libraries are under
`/usr/lib`; their static archive is tested with Ubuntu's shared METIS, because
that METIS package does not provide a static archive.

The local source archive is `docker/parmetis-4.0.3.tar.gz`. Build settings and
dependencies are recorded in `share/parmetis/build-config.json` under each Intel
prefix. See [ParMETIS build decisions](docker/parmetis-sources.md).

## Use Scotch and PT-Scotch

Select the compiler and MPI stack, then load the serial and parallel modules:

```bash
module load scotch
module load ptscotch
export SCOTCH_PTHREAD_NUMBER=2
```

Intel stacks provide `scotch/7.0.10` and `ptscotch/7.0.10`. GNU reuses Ubuntu's
installed version through `scotch/7.0.4` and `ptscotch/7.0.4`. The modules define
`GRF_SCOTCH*` and `GRF_PTSCOTCH*` paths and version variables. Scotch appears in
the compiler hierarchy; PT-Scotch appears in the MPI hierarchy.

The Intel builds enable pthreads and threaded MPI algorithms, with 32-bit graph
integers, 64-bit internal memory indices, and static/shared libraries compiled
with `-fPIC`. Fortran interfaces and EsMUMPS are included. METIS compatibility
libraries are disabled because native METIS and ParMETIS are already installed.

C clients must include `<stdint.h>` and `<stdio.h>` before `<scotch.h>`, and `<mpi.h>` before
`<ptscotch.h>`.

PT-Scotch applications must request and check `MPI_THREAD_MULTIPLE`:

```c
int provided;
MPI_Init_thread(&argc, &argv, MPI_THREAD_MULTIPLE, &provided);
if (provided < MPI_THREAD_MULTIPLE) MPI_Abort(MPI_COMM_WORLD, 1);
```

Ordinary `MPI_Init` does not request the required support. The example environment
variable selects two Scotch threads per MPI rank; choose a thread count suited
to the resources allocated to each rank. It is independent of OpenMP.

Both Intel library families share a coherent installation under
`/opt/intel-<compiler-major>/scotch/7.0.10`; the PT-Scotch prefix in the MPI
hierarchy links to it. See [Scotch build decisions](docker/scotch-sources.md)
for the complete settings, dependency packages, provenance, and tests.

## Use MUMPS

After selecting a compiler and MPI stack, load the matching ordering libraries
and solver:

```bash
module load metis parmetis scotch ptscotch mumps
export OMP_NUM_THREADS=2
export MKL_NUM_THREADS=2
export SCOTCH_PTHREAD_NUMBER=2
```

Intel stacks provide MUMPS **5.7.3**, compiled with MPI and OpenMP, all four
arithmetic types, and static/shared libraries using `-fPIC`. PORD, METIS,
ParMETIS, Scotch, and PT-Scotch orderings are enabled. ScaLAPACK and Intel-MPI
BLACS come from the matching oneMKL cluster packages.

GNU reuses Ubuntu's MUMPS **5.6.2**, which supports PORD but lacks the external
ordering backends. Its module is `mumps/5.6.2`; Intel modules are `mumps/5.7.3`.
Modules define `GRF_MUMPSROOT`, `GRF_MUMPSINC`, `GRF_MUMPSLIB`, `GRF_MUMPSBIN`,
and `GRF_MUMPS_VERSION`.

With threaded PT-Scotch, initialize MPI using `MPI_Init_thread` and verify
`MPI_THREAD_MULTIPLE`, as shown above. Choose thread counts for the resources
assigned to each MPI rank. Use the installed `share/mumps/Makefile.inc` for
compiler and linking settings. See [MUMPS build decisions](docker/mumps-sources.md)
for dependency selection, ABI settings, and validation details.

## Installed software

Both images include:

- GCC/G++, GFortran, OpenMPI, GDB, Git, and Python 3.
- Make, CMake, Ninja, pkg-config, Autoconf, Automake, and Libtool.
- Lmod and compiler/MPI environment modules.
- Ubuntu development packages for METIS, ParMETIS, Scotch/PT-Scotch,
  ARPACK/PARPACK, MUMPS, OpenBLAS, LAPACK, ScaLAPACK, HDF5, and zlib.
- Intel C/C++ and Fortran compilers, Intel MPI, CPU oneMKL, and their dependencies.

Ubuntu numerical libraries can be linked directly without loading library modules.
`hofem-dev` adds GiDPost, ARPACK/PARPACK, METIS, ParMETIS, Scotch/PT-Scotch, and MUMPS
modules, with source-built Intel libraries. Scotch builds also install Flex,
Bison, and bzip2/LZMA development packages.

Intel installations request these payload packages and their required dependencies
with `--no-install-recommends`:

```text
intel-oneapi-dpcpp-cpp-<compiler-series>
intel-oneapi-compiler-fortran-<compiler-series>
intel-oneapi-mpi-devel-<mpi-series>
intel-oneapi-mkl-core-devel-<mkl-series>
```

`hofem-dev` additionally installs version-matched `intel-oneapi-mkl-cluster-devel-<mkl-series>`
and cluster runtime payloads for MUMPS's ScaLAPACK/BLACS dependencies.
Complete oneAPI toolkit metapackages are not installed. Exact package versions and
toolchain series are recorded under `/usr/local/share/hofem/intel/`.

## Module organization

The module hierarchy is installed under `/opt/modulefiles`. Initially:

```text
MODULEPATH_ROOT=/opt/modulefiles
MODULEPATH=/opt/modulefiles/Core
```

Loading a compiler exposes its library and MPI modules. Loading MPI exposes modules
for libraries compiled with that compiler/MPI combination:

```text
Core/oneapi/compiler/2025.3.lua
  -> Compiler/intel/2025/
       impi/2021.17.lua -> MPI/intel/2025/impi/2021/

Core/gfortran/<version>.lua
  -> Compiler/gcc/<major>/
       openmpi/<version>.lua -> MPI/gcc/<major>/openmpi/<major>/
```

`grema-dev` contains the compiler/MPI modules, compiler dependency modules, directory
hierarchy, and generic library templates. `hofem-dev` adds GiDPost, ARPACK, METIS, and Scotch symlinks to
`Compiler/generic.lua`, and PARPACK/ParMETIS/PT-Scotch/MUMPS symlinks to `MPI/generic.lua`, for every stack. No `.modulerc.lua` files hide modules.
The reference hierarchy is stored under `/usr/local/share/hofem/modulefiles`.

## Check the environments

```bash
docker run --rm grema-dev grema-smoke-test
docker run --rm hofem-dev hofem-smoke-test
```

The toolchain test checks module visibility, GNU and Intel MPI with two ranks,
OpenMP, MKL, numerical linking, and C++ with TBB. It also checks that the base has
no GiDPost installation or generic library module symlinks.

The HOFEM test additionally checks both GiDPost releases for each compiler,
static/shared C and Fortran linking, HDF5 output, and PIC linking. These tests do
not compile the HOFEM application. It also checks ARPACK/PARPACK eigenvalues
using static and shared libraries, with PARPACK running on two MPI ranks.
To run just the eigenvalue tests, use `docker run --rm hofem-dev hofem-arpack-test`.
The full suite also checks METIS partition balance, edge cuts, ordering, the 32/32
ABI, and static/shared PIC linking. Run those checks separately with
`docker run --rm hofem-dev hofem-metis-test`.
ParMETIS tests check two-rank partitioning and ordering, matching MPI/METIS
libraries, and static/shared PIC linking. They are included in the full suite and
can be run separately with `docker run --rm hofem-dev hofem-parmetis-test`.
Scotch tests additionally exercise pthread contexts, `MPI_THREAD_MULTIPLE`,
serial/distributed partitions and ordering, and C/Fortran static/shared interfaces.
Run them separately with `docker run --rm hofem-dev hofem-scotch-test`.
MUMPS tests solve known systems in all four arithmetic types, check each enabled
ordering backend, exercise C/Fortran static/shared interfaces, and verify PIC.
Run them separately with `docker run --rm hofem-dev hofem-mumps-test`.

## Build options

GiDPost sources are bundled in `docker/gidpost-2.14.tar.gz` and
`docker/gidpost-2.9.tar.gz`. Their checksums are verified during the build; no
GiDPost source downloads are needed. See [source archive details](docker/gidpost-sources.md).

ARPACK/PARPACK use the local `docker/arpack-97.tar.gz` archive; no source
downloads are needed. Its checksum is pinned in `docker/build-arpack.sh`.

METIS uses the local `docker/metis-5.1.0.tar.gz` archive, with its checksum pinned
in `docker/build-metis.sh`. Its approved ABI and OpenMP settings are fixed in the
build script and recorded in each installation.

ParMETIS uses `docker/parmetis-4.0.3.tar.gz`, verified against the checksum in
`docker/build-parmetis.sh`. It retains the approved METIS ABI/OpenMP choices.

Scotch/PT-Scotch use `docker/scotch-v7.0.10.tar.gz`, verified by
`docker/build-scotch.sh`. Threading and integer settings are fixed in the script
and recorded in each Intel installation.

MUMPS uses `docker/MUMPS_5.7.3.tar.gz`, verified by `docker/build-mumps.sh`.
Its MPI/OpenMP, arithmetic, ordering, and LP64 choices are documented in
[MUMPS build decisions](docker/mumps-sources.md).

For `Dockerfile.hofem`, the available build arguments are:

| Argument | Default | Purpose |
| --- | --- | --- |
| `BUILD_JOBS` | `2` | Parallel source compilation jobs; ARPACK make targets run serially. |
| `GIDPOST_VERSIONS` | `"2.14 2.9"` | GiDPost releases to include. |

Optional standalone toolchain images can be built with fewer stacks:

```bash
docker build --target intel-2025 --platform linux/amd64 -t grema-dev:2025.3 hofem-dev-docker/
docker build --target gnu-dev -t grema-dev:gnu hofem-dev-docker/
```

These smaller images can be used independently. `Dockerfile.hofem` requires the
complete `grema-dev:latest` base with all three stacks.

## Limitations

- Ubuntu's parallel libraries use GNU/OpenMPI. Rebuild MPI-dependent libraries for
  Intel MPI before linking them into Intel applications.
- Fortran module files are compiler-specific.
- Legacy Intel `ifort`, `icc`, and `icpc` are not included.
- GiDPost 2.9's legacy `GiD_fWriteResultBlock` Fortran wrapper has an upstream
  pointer mismatch. Intel builds retain the diagnostic as a warning. That wrapper
  is not validated; the tested Fortran interface uses `ISO_C_BINDING` and scalar APIs.
- Base builds need Ubuntu and Intel APT access. Review dependency licenses before
  redistributing images.
