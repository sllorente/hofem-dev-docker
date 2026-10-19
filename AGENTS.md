# Repository Guidelines

## Project Structure & Module Organization

This repository is intended to provide a Docker-based development environment for HOFEM, GREMA’s electromagnetic solver using High Order Finite Elements. Currently, `README.md` is the only project file; no Dockerfile, application source, tests, or assets have been added.

The README lists the intended toolchain: Intel compilers, MKL, Intel MPI, Lmod, Gfortran, OpenMPI, and numerical libraries including METIS, ARPACK, MUMPS, and related parallel variants. Keep environment setup here and document any external HOFEM source checkout separately.

## Build, Test, and Development Commands

No build, run, or test commands are currently configured. When adding a Dockerfile, document its exact build command, required build context, and runtime options in the README’s `Usage` section. For example, a root Dockerfile could support `docker build -t hofem-dev .`.

Document bind mounts in `Volumes`, installed versions in `Tools installed`, and known constraints in `Issues & limitations`. Do not describe proposed commands as working until verified.

## Coding Style & Naming Conventions

Use descriptive filenames and consistent indentation within each file. For new Dockerfiles, use uppercase instructions and group related dependency installation steps. For shell scripts, include an explicit interpreter and quote variable expansions. Keep Markdown headings descriptive and commands in fenced code blocks. No formatter or linter is configured.

## Testing Guidelines

No test framework or coverage requirement exists yet. For environment changes, verify a clean image build and smoke-test affected compilers, MPI tools, and libraries inside the container. Record commands and results in the pull request, including any unavailable licensed dependencies.

## Commit & Pull Request Guidelines

There is no commit history establishing a message convention. Use concise, imperative subjects such as `Add GNU compiler environment`. Keep changes focused. Pull requests should explain the purpose, configuration changes, validation performed, and any related issue.

## Security & Configuration Tips

Keep credentials, compiler license files, and machine-specific paths out of version control and image layers. Document required external configuration without including secrets.
