# GREMA and HOFEM development images

Ubuntu 24.04 LTS environments for developing HOFEM, GREMA's electromagnetic
solver using High Order Finite Elements. Application sources are maintained
separately and shared with containers through a bind mount.

## Requirements to build and run

The host can use a different Linux distribution from the Ubuntu 24.04 environment
inside the image. It must have a compatible kernel, container support enabled,
and a working Docker Engine. The Intel stacks require an **x86-64/amd64 host**
and compatible CPU instructions. Specifying `--platform linux/amd64` selects the
image architecture; it does not by itself enable execution on an ARM host.

| Requirement | Building images | Running an existing image |
| --- | --- | --- |
| Docker Engine and access to its daemon | Required; use a current BuildKit-capable installation with the Buildx plugin | Required |
| Compose v2 (`docker compose`) | Optional; the build commands use Docker directly | Required only for the Compose workflow |
| Project files | Complete repository, including the bundled archives under `docker/` | The image; Compose also needs `compose.yaml` and `docker/entrypoint.sh` in their original relative layout |
| Network access | Ubuntu base image, Ubuntu/Intel package repositories, Intel signing key and any Dockerfile frontend downloads; numerical source archives are bundled | Needed to obtain an image unless supplied as a `docker save` archive; subsequent local launches can work offline |
| Disk space | Image layers, compiler packages, build cache and temporary compilation files | Image layers, container changes and application outputs |
| Memory and CPU | Enough for parallel compilation; `BUILD_JOBS` defaults to `2` for HOFEM libraries | Depends on the compiler/application workload and MPI process count |

No measured minimum RAM or disk capacity is established for this project. Allow
several tens of gigabytes for compiler images and additional space for build
cache, multiple image variants and application files. Reducing `BUILD_JOBS`
reduces concurrent compilation when memory is limited. Check space on the
Docker storage filesystem, not just the workspace partition: rootful Docker
commonly uses `/var/lib/docker`, and containerd-backed installations may also
use `/var/lib/containerd`.

Host compilers, Intel oneAPI, MPI, Lmod and numerical libraries are not required;
they are installed inside the images. Building the HOFEM extension requires the
selected GREMA base image first. An end user can instead import a supplied
archive with `docker load -i /path/to/hofem-dev.tar` and use its existing tag.

An administrator installs/configures the host runtime. The commands below assume
the caller is authorized to use the rootful Docker daemon, through sudo or an
administrator-approved Docker group membership. Docker group access grants
root-level capabilities on the host. Running as `developer` or setting a container
UID does not grant daemon access. For users who cannot receive that access, see
[rootless Docker](README_rootless_docker.md) or [Podman](README_podman.md);
their UID mapping and launch configuration differ from this rootful workflow.
See [Docker post-installation guidance](https://docs.docker.com/engine/install/linux-postinstall/).

### Debian and Ubuntu hosts

Use one coherent package source: distribution packages or Docker CE from
Docker's official repository. Have the administrator review existing runtime
packages before switching sources. Example installations from distribution
repositories are:

```bash
# Debian 13
sudo apt update
sudo apt install docker.io docker-cli docker-buildx docker-compose

# Ubuntu 24.04, with the universe repository enabled
sudo apt update
sudo apt install docker.io docker-buildx docker-compose-v2
```

The Compose package name is distribution-specific: Debian 13's `docker-compose`
provides v2; Debian 12's standard package provides legacy v1 and needs a separately
provisioned v2 plugin for this README's Compose commands. Ubuntu's
[`docker-compose-v2`](https://packages.ubuntu.com/noble/docker-compose-v2)
provides the required plugin. Buildx is packaged as
[`docker-buildx`](https://packages.debian.org/trixie/docker-buildx).

As an alternative, configure the appropriate
[Docker CE Debian repository](https://docs.docker.com/engine/install/debian/)
or [Docker CE Ubuntu repository](https://docs.docker.com/engine/install/ubuntu/),
then install `docker-ce`, `docker-ce-cli`, `containerd.io`,
`docker-buildx-plugin` and `docker-compose-plugin`. Use the repository matching
the actual host distribution and release; an Ubuntu container base does not
mean the host should use Ubuntu repositories.

On a systemd host, the administrator can start and enable the system daemon with
`sudo systemctl enable --now docker`.

To run this README's rootful Docker commands **without sudo**, the user must
belong to the `docker` group. An administrator can add the account with:

```bash
sudo usermod -aG docker your_username
```

Replace `your_username` with the account that will build/run the images, then
log out and log back in so the new membership takes effect. Verify it with
`id -nG`; the output must include `docker`.

**Docker group membership grants root-level access to the host**, because it
allows controlling the rootful daemon, including mounting host filesystems and
starting privileged containers. Running the image as a non-root user does not
remove those host capabilities. Grant membership only to trusted accounts with
administrator approval. If that access is prohibited, use sudo where authorized
or the separate rootless Docker/Podman workflows; do not make the Docker socket
world-writable.

From the authorized account, check:

```bash
docker version
docker info
docker buildx version
docker compose version
```

`docker version` must reach the server, not merely print a client version.
Use sudo for daemon-dependent checks if that is the approved access method.
These checks do not build or run a container.

### RHEL-compatible hosts

Use a Docker installation compatible with the actual distribution and release,
following its administrator/vendor guidance. Docker publishes installation
instructions for maintained [RHEL releases](https://docs.docker.com/engine/install/rhel/)
and [CentOS Stream releases](https://docs.docker.com/engine/install/centos/);
Rocky Linux and AlmaLinux deployments should use a site-approved compatible
package source. CentOS 7 is a legacy platform outside the current Docker
installation support matrix; archived packages and the image's compatibility
require separate validation.

Once the appropriate Docker CE repository is configured, the usual package
installation and daemon startup commands are:

```bash
sudo dnf install docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

Verify access using the same `docker version`, `docker info`, Buildx and Compose
checks shown above. Some distributions provide `podman-docker`, which makes the
`docker` command invoke Podman. For this workflow, confirm that the command
connects to Docker Engine; use the separate Podman guide when choosing Podman.

SELinux may require suitable labels on bind-mounted workspace directories and
the live entrypoint script. For a dedicated workspace, Docker's `:Z` volume
option is one possible private-label configuration; shared paths may require
`:z` or administrator-managed labels. Relabeling changes host metadata, so apply
it only to appropriate project paths. Do not relabel an entire home/system tree
or disable SELinux to resolve a mount issue. The supplied Compose file does not
automatically relabel its mounts. Rootful UID/GID matching still applies in
addition to SELinux permissions.

## Images and tags

`grema-dev` supplies development tools and compiler/MPI stacks. `hofem-dev`
extends it with numerical libraries and their environment modules.

| Image tag | Compiler/MPI stacks | Dockerfile stage or base |
| --- | --- | --- |
| `grema-dev:latest` | GNU/OpenMPI, Intel 2025.3/MPI 2021.17, newest available Intel pair | `development` stage in `Dockerfile` |
| `hofem-dev:latest` | Same stacks, with HOFEM libraries | `Dockerfile.hofem`, based on `grema-dev:latest` |
| `grema-dev:2025.3` | GNU/OpenMPI and Intel 2025.3/MPI 2021.17 | `intel-2025` stage in `Dockerfile` |
| `hofem-dev:2025.3` | Same two stacks, with HOFEM libraries | `Dockerfile.hofem`, based on `grema-dev:2025.3` |
| `grema-dev:gnu` | GNU/OpenMPI only | `gnu-dev` stage in `Dockerfile` |

Use **`2025.3`** consistently for image tags. The stage name **`intel-2025`** is
independent of the tag: `--target` selects a Dockerfile stage, while `-t` names
its resulting image. Without `--target`, Docker builds the final `development`
stage, including the newer Intel pair.

`Dockerfile.hofem` requires GNU and at least one Intel compiler/MPI profile.
Library builds and modules follow the profiles installed in the selected base;
`grema-dev:gnu` is a standalone toolchain image, not a supported HOFEM base.

## Build the images

Run all build commands below from the **parent directory of `hofem-dev-docker/`**.
Intel images require `linux/amd64`.

### All three stacks: `latest`

Build the toolchain base, then add the HOFEM libraries:

```bash
docker build --platform linux/amd64 \
    -t grema-dev:latest hofem-dev-docker/

docker build --platform linux/amd64 \
    -f hofem-dev-docker/Dockerfile.hofem \
    -t hofem-dev:latest hofem-dev-docker/
```

The newest Intel compiler/MPI series is resolved from Intel's signed APT metadata
when the base is built. The last validated full-stack image contains compiler
2026.2.0/MPI 2021.19.0 alongside compiler 2025.3.3/MPI 2021.17.2.

### GNU and Intel 2025.3 only: `2025.3`

Select the `intel-2025` stage to omit the newer Intel compiler and MPI:

```bash
docker build --platform linux/amd64 --target intel-2025 \
    -t grema-dev:2025.3 hofem-dev-docker/

docker build --platform linux/amd64 \
    -f hofem-dev-docker/Dockerfile.hofem \
    --build-arg GREMA_IMAGE=grema-dev:2025.3 \
    -t hofem-dev:2025.3 hofem-dev-docker/
```

Skip the base build if the desired `grema-dev` image already exists. Building
`hofem-dev` adds libraries without reinstalling compilers or MPI. Changing the
base requires building the libraries for its installed stacks.

### GNU-only toolchain

```bash
docker build --target gnu-dev -t grema-dev:gnu hofem-dev-docker/
```

### Build arguments and paths

The final argument, `hofem-dev-docker/`, is the **build context**: the directory
containing the Dockerfiles, scripts, modulefiles, and bundled sources. Adjust it
and the `-f` path if the repository is elsewhere. `-f` selects a Dockerfile;
`-t` sets the image name and tag; `--build-arg` overrides a build argument.

`Dockerfile.hofem` accepts:

| Argument | Default | Purpose |
| --- | --- | --- |
| `GREMA_IMAGE` | `grema-dev:latest` | Toolchain base to extend |
| `BUILD_JOBS` | `2` | Parallel compilation jobs; ARPACK targets run serially |
| `GIDPOST_VERSIONS` | `"2.14 2.9"` | GiDPost releases to install |

Source archives are bundled under `docker/` and their checksums are verified.
Image builds do not download library sources. Base installation and additional
Ubuntu/Intel dependency packages require APT access.

## Run a container

Start an interactive shell with a stable hostname and your host UID/GID:

```bash
docker run --rm -it \
    --hostname hofem-build \
    --user "$(id -u):$(id -g)" \
    --env HOME=/tmp \
    -v "/absolute/path/to/directory:/workspace" \
    hofem-dev:latest
```

Use `hofem-dev:2025.3` for the Intel 2025.3 variant, or a `grema-dev` tag for the
toolchain environment without the additional HOFEM library builds.

- `--rm` removes the container when you exit; `-it` provides an interactive terminal.
- `--hostname hofem-build` fixes the hostname across launches. Replace it with
  the hostname expected by your build configuration.
- `--user "$(id -u):$(id -g)"` selects your host UID and primary GID instead of
  the image's default `developer` UID 10001. Run this command from your host shell.
- `--env HOME=/tmp` gives the selected user a writable home location. Its contents
  disappear when the container is removed.
- `-v HOST_DIRECTORY:CONTAINER_DIRECTORY` shares a host directory with the
  container. Existing host permissions still apply; newly created files belong
  to the selected host UID/GID.

For example, share the directory from which you launch Docker:

```bash
docker run --rm -it \
    --hostname hofem-build \
    --user "$(id -u):$(id -g)" \
    --env HOME=/tmp \
    -v "$PWD:/workspace" \
    hofem-dev:latest
```

Your current host directory becomes `/workspace` inside the container, where the
shell starts. Launching from `/home/user/hofem` makes that directory available as
`/workspace`. Changes there persist on the host; other container changes disappear
with `--rm`.

Numeric IDs do not create a named account inside the container. The prompt or
`whoami` may report an unknown username; filesystem permissions use the numeric
IDs. If access depends on a supplementary host group, add `--group-add GROUP_ID`.

### Run with Docker Compose

As an alternative to `docker run`, `compose.yaml` stores the image, hostname,
user IDs, workspace mount, and interactive-shell settings. Build the image first;
this configuration uses local images and does not build or pull them.

Compose also mounts `docker/entrypoint.sh` read-only and runs it with Bash.
Edits to that file take effect the next time you start a container with Compose,
without rebuilding the images. Existing container sessions keep their current
environment. Plain `docker run` still uses the entrypoint embedded in the image.

From the repository directory, set your host IDs and the absolute directory to
share, then start a shell:

```bash
export LOCAL_UID="$(id -u)"
export LOCAL_GID="$(id -g)"
export LOCAL_USER="$(id -un)"
export WORKSPACE="/absolute/path/to/hofem"
docker compose run --rm hofem
```

Set `WORKSPACE="$PWD"` to share the current directory. The default image is
`hofem-dev:latest`. To select the Intel 2025.3 variant:

```bash
IMAGE_TAG=2025.3 docker compose run --rm hofem
```

The hostname defaults to `hofem-build`; override it with `HOFEM_HOSTNAME` when
your build requires another name. The entrypoint initially runs as container
root to create an account matching `LOCAL_UID`, `LOCAL_GID`, and `LOCAL_USER`,
then drops privileges before loading modules and starting the shell. An existing
account with that UID is reused; a name already assigned to another UID gets a
numeric suffix. `HOME` points to the account's writable home directory. This does
not require host root or `--privileged`, and workspace ownership remains tied to
your host UID/GID. Compose
substitutes environment variables; it does not execute `$(id -u)` in YAML or
`.env` files, so set the IDs in your host shell as shown.

## Select a compiler and MPI stack

Lmod is initialized at startup. No modules load automatically, and `module avail`
initially shows only `Core`. System GCC, GFortran, and OpenMPI are also available
without loading modules.

### GNU/OpenMPI

```bash
module purge
module load gfortran openmpi
```

### Intel 2025.3/MPI 2021.17

```bash
module purge
module load oneapi/compiler/2025.3 impi/2021.17
```

### Newest installed Intel pair

```bash
module purge
module load oneapi/compiler
module load impi
```

The unversioned commands select the newest installed modules; in the `2025.3`
image, that is the 2025.3/2021.17 pair. Use `module purge` before switching stacks
and `module swap` when replacing one library version within the current stack.
For `docker exec`, use `bash -lc` to initialize Lmod.

Compiler modules define `CC`, `CXX`, `FC`, and `F77`. Intel selects `icx`, `icpx`,
and `ifx`; its MPI module defines `MPICC=mpiicx`, `MPICXX=mpiicpx`, `MPIFC=mpiifx`,
and `MPIROOT`. Intel compiler modules also load their MKL, TBB, UMF, and debugger
components when available.

## Library modules

Select the compiler first, then MPI for parallel libraries. Modules expose
`GRF_<NAME>ROOT`, `GRF_<NAME>INC`, `GRF_<NAME>LIB`, `GRF_<NAME>BIN`, and
`GRF_<NAME>_VERSION`. For example, GiDPost defines `GRF_GIDPOSTLIB`.

| Library | Module after selecting the stack | Intel build | GNU installation |
| --- | --- | --- | --- |
| GiDPost | `gidpost/2.14` or `gidpost/2.9` | Both releases | Both releases; existing objects reused |
| ARPACK/PARPACK | `arpack/97`, `parpack/97` | Supplied release 97 | Ubuntu 3.9.1, exposed through `/97` compatibility aliases |
| METIS | `metis/5.1.0` | 5.1.0 | Ubuntu 5.1.0; shared library only |
| ParMETIS | `parmetis/4.0.3` | 4.0.3 | Ubuntu 4.0.3/OpenMPI |
| Scotch/PT-Scotch | `scotch`, `ptscotch` | 7.0.10 | Ubuntu 7.0.4 |
| MUMPS | `mumps/5.7.3` | 5.7.3 | Source-built 5.7.3 with all ordering backends |

Source-built libraries provide static and shared variants compiled with `-fPIC`.
Distribution libraries retain their package settings. GNU libraries already
available in the base are reused, except MUMPS, which is rebuilt to enable all
ordering backends. The source-build requirements do not imply
that Ubuntu supplies a static archive for every library.

### GiDPost and embedded HDF5

```bash
module load gidpost/2.14
module swap gidpost/2.14 gidpost/2.9
```

Both releases include C/Fortran static and shared libraries and a compiler-specific
`gidpost.mod`. Compile a Fortran client using shared libraries with:

```bash
"$FC" -fPIC -I "$GRF_GIDPOSTINC" program.f90 \
    -L "$GRF_GIDPOSTLIB" -lgidpost_fortran -lgidpost
```

To select the static GiDPost libraries explicitly:

```bash
"$FC" -fPIC -I "$GRF_GIDPOSTINC" program.f90 \
    "$GRF_GIDPOSTLIB/libgidpost_fortran.a" "$GRF_GIDPOSTLIB/libgidpost.a" \
    -lsz -lz -ldl -lpthread -lm
```

HDF5 1.10.10 core and HL are embedded in `libgidpost.a` and `libgidpost.so`.
GiDPost clients do not need separate HDF5 link flags. Embedded HDF5 symbols are
private, allowing applications to use an independent HDF5 library. Static clients
still need the external dependencies shown above; shared GiDPost records them.

### ARPACK and graph libraries

```bash
module load arpack/97 parpack/97
module load metis/5.1.0 parmetis/4.0.3
module load scotch ptscotch
```

- Intel ARPACK/PARPACK builds include all four arithmetic types and use sequential
  LP64 MKL; PARPACK uses the matching MPI implementation.
- METIS and ParMETIS use 32-bit graph indices and reals, with OpenMP disabled.
  ParMETIS reuses the matching METIS; static consumers link both and MPI. GNU's
  static ParMETIS is used with shared METIS because Ubuntu does not provide METIS's
  static archive.
- Intel Scotch/PT-Scotch enable pthreads and threaded MPI algorithms, with 32-bit
  graph integers and 64-bit internal indices. Fortran interfaces and EsMUMPS are
  included; METIS compatibility libraries are disabled.

### MUMPS and threaded MPI

Load MUMPS together with its ordering dependencies:

```bash
module load metis parmetis scotch ptscotch mumps
export OMP_NUM_THREADS=2
export MKL_NUM_THREADS=2
export SCOTCH_PTHREAD_NUMBER=2
```

MUMPS is compiled for every stack with MPI/OpenMP, all four arithmetic types,
and PORD, METIS, ParMETIS, Scotch, and PT-Scotch orderings. Intel uses matching
oneMKL LP64 libraries, ScaLAPACK, and Intel-MPI BLACS. GNU uses OpenMPI, OpenBLAS,
LAPACK, and Ubuntu's ScaLAPACK. Its `mumps/5.7.3` module selects the source-built
installation under `/opt/gcc-<major>/openmpi-<major>/mumps/5.7.3`, including its
Fortran modules. Use the installed `share/mumps/Makefile.inc` for link settings.

PT-Scotch clients, including MUMPS applications using that backend, must request
and check `MPI_THREAD_MULTIPLE`:

```c
int provided;
MPI_Init_thread(&argc, &argv, MPI_THREAD_MULTIPLE, &provided);
if (provided < MPI_THREAD_MULTIPLE) MPI_Abort(MPI_COMM_WORLD, 1);
```

Include `<stdint.h>` and `<stdio.h>` before `<scotch.h>`, and `<mpi.h>` before
`<ptscotch.h>`. Ordinary `MPI_Init` does not request the required thread support.
Choose the thread counts above for the resources assigned to each MPI rank;
they are examples, not fixed image defaults. Scotch pthreads are independent of
OpenMP.

## Validate an image

Run these after building the selected variant:

```bash
docker run --rm grema-dev:latest grema-smoke-test
docker run --rm hofem-dev:latest hofem-smoke-test
```

For the 2025.3 variant, use `grema-dev:2025.3` and `hofem-dev:2025.3` instead.
Tests follow the toolchain profiles installed in each image. The full HOFEM suite
checks compiler/MPI environments, module visibility, static/shared C and Fortran
linking, PIC, GiDPost HDF5 files, eigenvalues, graph partitioning/ordering, and
MUMPS solutions. It does not compile the HOFEM application.

Run individual library checks by replacing the command in:

```bash
docker run --rm hofem-dev:latest hofem-gidpost-hdf5-test
```

Other commands are `hofem-arpack-test`, `hofem-metis-test`, `hofem-parmetis-test`,
`hofem-scotch-test`, and `hofem-mumps-test`.

## Build details and module hierarchy

`grema-dev` includes development tools, Lmod, Ubuntu numerical development
packages, and the selected compiler/MPI stacks. `hofem-dev` adds the stack-specific
library builds and modules. Ubuntu numerical libraries can also be linked directly.

Intel installations use versioned compiler, MPI, and oneMKL core payload packages
with `--no-install-recommends`, rather than complete oneAPI toolkit metapackages.
HOFEM adds matching oneMKL cluster payloads for MUMPS. Exact Intel versions are
recorded in `/usr/local/share/hofem/intel/`; GNU library package versions are
recorded under `/usr/local/share/hofem/<library>/`.

Modules live under `/opt/modulefiles`, with only `Core` in the initial
`MODULEPATH`. Loading a compiler exposes its compiler hierarchy; loading MPI
exposes its MPI hierarchy:

```text
Core/oneapi/compiler/2025.3.lua
  -> Compiler/intel/2025/
       impi/2021.17.lua -> MPI/intel/2025/impi/2021/

Core/gfortran/<version>.lua
  -> Compiler/gcc/<major>/
       openmpi/<version>.lua -> MPI/gcc/<major>/openmpi/<major>/
```

Serial library modules link to `Compiler/generic.lua`; MPI library modules link
to `MPI/generic.lua`. The base preserves the hierarchy and templates; HOFEM adds
library links for its installed stacks. No `.modulerc.lua` files hide modules.
The reference hierarchy is under `/usr/local/share/hofem/modulefiles`.

Intel serial libraries generally install under `/opt/intel-<major>/<library>/...`,
and MPI libraries under `/opt/intel-<major>/impi-<major>/<library>/...`.
Scotch/PT-Scotch share an installation, and GiDPost's private HDF5 is outside
`LD_LIBRARY_PATH` and the module hierarchy. Consult module variables for actual
paths and the following documents for archives, checksums, settings, and exceptions:

| Library | Build documentation |
| --- | --- |
| GiDPost and embedded HDF5 | [Sources and linking](docker/gidpost-sources.md) |
| ARPACK/PARPACK | [Build details](docker/arpack-sources.md) |
| METIS | [Build decisions](docker/metis-sources.md) |
| ParMETIS | [Build decisions](docker/parmetis-sources.md) |
| Scotch/PT-Scotch | [Build decisions](docker/scotch-sources.md) |
| MUMPS | [Build decisions](docker/mumps-sources.md) |

## Docker storage and cleanup

```bash
docker image ls
docker system df
docker image prune
```

`docker image prune` asks for confirmation before removing unused dangling images,
often shown as `<none>:<none>` after rebuilds. Shared layers and build cache may
remain, so displayed image sizes do not add up to actual disk usage.

## Limitations

- Ubuntu's parallel numerical libraries use GNU/OpenMPI. Intel builds must use
  their matching MPI libraries and wrappers.
- Fortran module files are compiler-specific; select the matching stack before
  compiling or running applications.
- Legacy Intel `ifort`, `icc`, and `icpc` are not included.
- GiDPost 2.9's legacy `GiD_fWriteResultBlock` Fortran wrapper has an upstream
  pointer mismatch. Intel builds retain the diagnostic as a warning; that wrapper
  is not validated. Tests exercise the `ISO_C_BINDING` interface and scalar APIs.
