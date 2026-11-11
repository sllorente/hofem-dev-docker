# Repository Guidelines

## Project Structure & Module Organization

`Dockerfile` defines the `grema-dev` toolchain base. `Dockerfile.hofem` extends the base selected by `GREMA_IMAGE` with HOFEM libraries. Supported bases contain GNU and at least one Intel compiler/MPI profile; the default has all three stacks. Keep library compilation out of the base.

`docker/` contains installation scripts and bundled sources; `modulefiles/` contains compiler/MPI modules, generic templates, and reference library links. The base preserves the hierarchy and templates without generic library symlinks; the derived image adds links for its libraries. `tests/` contains smoke tests. HOFEM application sources are maintained separately.

## Build, Test, and Development Commands

From the repository root, when builds are authorized:

- `docker build -t grema-dev .`: build the complete toolchain base.
- `docker build -f Dockerfile.hofem -t hofem-dev .`: add libraries to that base.
- `docker run --rm grema-dev grema-smoke-test`: test the base.
- `docker run --rm hofem-dev hofem-smoke-test`: test toolchains and libraries.

The README documents building the toolchain base before the library image and using bind mounts. Fresh builds must not depend on pre-existing GREMA/HOFEM images. Do not describe unverified commands as tested.

## Coding Style & Library Builds

Use consistent indentation, uppercase Dockerfile instructions, explicit shell interpreters, and quoted variable expansions. No formatter is configured.

Compile all source-built C, C++, and Fortran code, static libraries, and validation programs with `-fPIC`. For CMake, enable `CMAKE_POSITION_INDEPENDENT_CODE` and set language flags explicitly. Distribution packages retain upstream settings.

For every source-built library and compiler stack, always generate the static library (`.a`) and, when supported, the shared library (`.so`). Preserve both in the installation prefix; document limitations preventing shared builds.

Before building for GNU, check whether the requested library version is already available in the image. Reuse it instead of rebuilding. Generation requirements apply only when source builds are needed.

MUMPS is an explicit exception: build 5.7.3 for GNU/OpenMPI with all ordering backends, because Ubuntu's MUMPS provides only PORD. Its module must select the source-built prefix under `/opt/gcc-<major>/openmpi-<major>/mumps/5.7.3`.

After successful compilation and validation, update `docker/` and `Dockerfile.hofem` for the next image build. Preserve GNU reuse, library variants, and PIC flags. Defer image builds until explicitly requested.

## Testing Guidelines

Test affected compilers, MPI tools, modules, and static/shared libraries inside containers. Use existing images for compilation checks unless image builds are requested. Record validation and limitations.

## Commit & Pull Request Guidelines

Use concise, imperative commit subjects. Keep changes focused. Pull requests should explain the purpose, configuration changes, validation, and related issues.

## Security & Configuration Tips

Keep credentials, license files, and machine-specific paths out of version control and image layers.
