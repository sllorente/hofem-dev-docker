# HOFEM development dockerized

## About

Configure a machine with all the tools and dependencies ready to compile and develop HOFEM software.

HOFEM is software developed by the GREMA research group to solve electromagnetic problems using High Order Finite Elements.

## Usage

The Dockerfile uses Ubuntu 24.04 LTS. Its default `development` target includes
GNU tools and two Intel toolchains in the same image, and requires `linux/amd64`:

| Compiler module | Intel C/C++ and Fortran | MPI module | CPU oneMKL |
| --- | --- | --- | --- |
| `oneapi/compiler/2025.3` | Latest 2025.3 patch | `impi/2021.17` | Latest 2025.3 patch |
| `oneapi/compiler/2026.2` (currently latest) | Latest available | `impi/2021.19` (currently latest) | Latest available |

The latest series are resolved from Intel's signed APT metadata at build time.
At the last repository check, these were compiler 2026.2.0 and MPI 2021.19.0.

Build the complete environment (the Intel packages require several GB of disk space):

```bash
docker build --platform linux/amd64 -t hofem-dev .
```

Run an interactive container and share a host directory with it:

```bash
docker run --rm -it -v "/absolute/path/to/directory:/workspace" hofem-dev
```

The `-v` parameter uses the form `HOST_DIRECTORY:CONTAINER_DIRECTORY`. The host
directory becomes accessible at the specified path inside the container. Here,
`/absolute/path/to/directory` on your machine appears as `/workspace`, which is
also the container's working directory. Changes to files in this shared directory
are visible on both sides and remain on the host after the container exits.

For example:

```bash
docker run --rm -it -v "$PWD:/workspace" hofem-dev
```

`$PWD` is the current directory where you launch Docker. If you run this command
from `/home/user/hofem`, that directory appears as `/workspace` inside the
container. The `--rm` option removes the container when you exit, and `-it`
provides an interactive terminal.

To include only the 2025.3 compiler and MPI 2021.17 pair:

```bash
docker build --target intel-2025 --platform linux/amd64 -t hofem-dev:2025.3 .
```

For a smaller environment with GNU tools only, build the `gnu-dev` target:

```bash
docker build --target gnu-dev -t hofem-dev:gnu .
docker run --rm -it -v "/absolute/path/to/directory:/workspace" hofem-dev:gnu
```

The default shell uses the system GCC, Gfortran, and OpenMPI. No modules are
preloaded. Lmod is initialized for interactive shells and commands launched
through the entrypoint; initially `module avail` shows only `Core` modules.

To activate the requested Intel pair inside the container:

```bash
module load oneapi/compiler/2025.3
module load impi/2021.17
icx --version
ifx --version
mpirun -V
```

Select the latest pair using the versions shown by `module avail`:

```bash
module purge
module load oneapi/compiler/2026.2
module load impi/2021.19
```

The compiler module also loads its TBB and UMF dependencies, with MKL and the
debugger when available. Compiler and MPI families each allow one implementation
at a time. Use `module purge` before changing the complete toolchain; avoid
sourcing global `setvars.sh`, which bypasses the hierarchy.

For the GNU toolchain, select the installed versions shown by `module avail`:

```bash
module purge
module load gfortran
module load openmpi
module load metis arpack gidpost parmetis parpack mumps
```

The GNU modules use Ubuntu's existing compiler, MPI, and library installations.
Library modules expose the supplied `GRF_<LIBRARY>ROOT`, `GRF_<LIBRARY>LIB`,
`GRF_<LIBRARY>INC`, and related variables without adding system library paths
to `LD_LIBRARY_PATH`.

For commands launched with `docker exec`, start a Bash login shell (`bash -lc`)
to initialize Lmod. Intel activation is explicit in each shell.

Run the environment smoke tests after building the chosen image:

```bash
docker run --rm hofem-dev hofem-smoke-test
docker run --rm hofem-dev:2025.3 hofem-smoke-test
docker run --rm hofem-dev:gnu hofem-smoke-test
```

The tests compile and run two MPI ranks, check OpenMP and numerical-library
linking, generate a GiDPost result file, compile its Fortran interface, and check
each installed Intel pair, C/C++ compilation with TBB, MPI, MKL, module hierarchy
visibility, and purging. They do not compile HOFEM; mount your HOFEM checkout and
use that project's build instructions.

## Modulefile hierarchy

The repository's `modulefiles/` contains the supplied Intel modules and generic
library modulefiles, with relative symlinks preserved. The image installs the
hierarchy at `/opt/modulefiles` and sets:

```text
MODULEPATH_ROOT=/opt/modulefiles
MODULEPATH=/opt/modulefiles/Core
```

Loading modules extends the search path in stages:

```text
Core/oneapi/compiler/2025.3.lua
  -> Compiler/intel/2025/
       impi/2021.17.lua -> MPI/intel/2025/impi/2021/
Core/gfortran/<installed-version>.lua
  -> Compiler/gcc/<major>/
       openmpi/<installed-version>.lua -> MPI/gcc/<major>/openmpi/<major>/
```

Build-time configuration derives GNU and latest Intel module versions from the
installed packages. The original reference hierarchy is also stored at
`/usr/local/share/hofem/modulefiles`. The supplied templates have been adjusted
for the `oneapi/` namespace and the installed TBB and Libfabric layouts.

Supplied Intel library modules expect separate installations such as
`/opt/intel-2025/metis/5.2.1` and
`/opt/intel-2025/impi-2021/mumps/5.7.3`. Those Intel builds are not installed by
this Dockerfile. Their reference modulefiles remain in the hierarchy but are
hidden from normal listings while their prefixes are absent; explicitly loading
one reports its missing build directory. Ubuntu library modules are exposed only
through the GNU hierarchy. To make a subsequently installed Intel library build
visible, rerun `python3 /usr/local/sbin/hofem-configure-modules intel COMPILER MPI MKL`
as root using the relevant release series (for example, `2025.3 2021.17 2025.3`).

## Tools installed

- GCC/G++, Gfortran, GNU OpenMP, OpenMPI, GDB, Git, and Python 3.
- Make, CMake, Ninja, pkg-config, Autoconf, Automake, and Libtool.
- Lmod environment modules.
- Ubuntu development packages for METIS, ParMETIS, Scotch/PT-Scotch,
  ARPACK/PARPACK, MUMPS, OpenBLAS, LAPACK, ScaLAPACK, HDF5, and zlib.
- GiDPost 2.14, compiled from its official source with HDF5 and Fortran bindings.
  Headers and the shared library are installed under `/usr/local/include` and
  `/usr/local/lib`. The Fortran interface source is at
  `/usr/local/share/gidpost/gidpost_interface.f90`; compile it with your chosen
  Fortran compiler before using its module.
- Intel targets: Intel C/C++ (`icx`/`icpx`) and Fortran (`ifx`) compilers,
  CPU oneMKL development libraries, and Intel MPI development tools.

Only these versioned Intel component packages are requested, plus their required
dependencies, with `--no-install-recommends`:

```text
intel-oneapi-dpcpp-cpp-<compiler-series>
intel-oneapi-compiler-fortran-<compiler-series>
intel-oneapi-mpi-devel-<mpi-series>
intel-oneapi-mkl-core-devel-<mkl-series>
```

No complete toolkit, C++ compiler wrapper, or MKL development metapackage is
installed. Intel's required dependencies may still include tools such as its
debugger; dependencies are not bypassed. MKL is limited to CPU core libraries
and headers, without SYCL or Intel MKL cluster development packages. Ubuntu's
OpenMPI ScaLAPACK remains available for the GNU toolchain.

Exact requested-package versions are recorded inside the image in
`/usr/local/share/hofem/intel/2025.3.packages` and `latest.packages`.
Docker may reuse cached Intel layers: use `docker build --no-cache ...` when you
want to refresh the latest releases. The 2025.3 target stays within its specified
compiler/MPI release series.

GiDPost's archive is checked against a SHA-256 hash.
To change its release, override both `GIDPOST_VERSION` and `GIDPOST_SHA256` with
`--build-arg`. `BUILD_JOBS` controls its compilation parallelism (default: 2).

## Issues & limitations

- Ubuntu's parallel libraries are built for GNU/OpenMPI. Build and run programs
  that use them with `/usr/bin/mpifort.openmpi` and `/usr/bin/mpirun.openmpi`.
  Rebuild MPI-dependent libraries for Intel MPI before linking them into an Intel
  MPI application. Fortran module files also depend on the compiler that built them.
- Modern Intel compilers provide `ifx`, `icx`, and `icpx`; legacy `ifort`, `icc`,
  and `icpc` are not included.
- ParMETIS comes from Ubuntu's `multiverse` component and has its own license
  terms. Review dependency licenses before redistributing the image.
- Intel package installation needs access to `apt.repos.intel.com`; GiDPost
  compilation needs access to `downloads.gidsimulation.com`.

Installation references: [Intel oneAPI APT setup](https://www.intel.com/content/www/us/en/docs/oneapi-toolkit/installation-guide-linux/latest/install-oneapi-toolkit-with-apt.html)
and [official GiDPost release](https://www.gidsimulation.com/downloads/gidpost-2-14-library-to-write-postprocess-results-for-gid-in-ascii-binary-or-hdf5-format/).
