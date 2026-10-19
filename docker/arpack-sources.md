# ARPACK/PARPACK 97

The supplied `arpack-97.tar.gz` archive is treated as release 97 for both libraries.
Its SHA-256 is:

```text
3c0e71948573d61147a0f25c15a83f5ed4ed1fcbb01b244d5e12477618781f82
```

The archive has one top-level `ARPACK/README` covering both serial ARPACK and
parallel PARPACK. There is no separate `PARPACK/README`. The MPI source and
example makefiles provide additional build instructions.

## Source builds

`build-arpack.sh` follows the README's `ARmake.inc` configuration and `make lib` /
`make plib` targets. It builds all four supported precisions for each Intel stack.

- Use installed MKL BLAS/LAPACK instead of rebuilding the bundled copies.
- Retain the supplied `SECOND` implementation, which already uses `CPU_TIME`.
- Copy the selected Intel MPI's `mpif.h` into the three MPI source/example
  directories specified by the README.
- Use `ifx` for serial sources and `mpiifx` for MPI sources. The MPI makefiles
  invoke `FC`, so the parallel build explicitly overrides it with the MPI wrapper.
- Compile every object with `-O2 -fPIC` and use sequential MKL with LP64 integers.
- Fix the spaces preceding the unused top-level `help` recipe to a Makefile tab.
- Build serially because the precision targets update the same archive.

The archive contains both static-library targets. The build script additionally
links shared libraries from all archive objects with `--no-undefined`. PARPACK
links against its matching ARPACK build and Intel MPI. This also validates PIC.
The upstream Makefiles print harmless duplicate-rule warnings.

The README mentions historical `patch.tar.gz` and `ppatch.tar.gz` downloads.
Neither is supplied here. Builds use exactly the provided archive and the
configuration changes above, without downloading or claiming additional patches.

## GNU libraries and module names

GNU reuses the image's Ubuntu `libarpack2-dev` and `libparpack2-dev` installations.
No replacement GNU libraries are compiled. Their package versions are recorded
in `/usr/local/share/hofem/arpack/gnu.packages`.

The module names are `arpack/97` and `parpack/97` for all stacks. For GNU, these
are aliases for the installed system libraries, not claims that Ubuntu's package
is the supplied release 97. The modules expose `/usr` and the multiarch library
path. Intel modules expose the source-built version under `/opt/intel-<major>`.

## Validation

`hofem-arpack-test` solves a diagonal eigenvalue problem with known eigenvalues
46, 47, and 48. It tests static and shared linking for every compiler stack and
runs PARPACK on two MPI ranks. It also checks entry points for all four precisions,
matching Intel library paths, and absence of text relocations in Intel shared
libraries. The complete `hofem-smoke-test` invokes these tests as well.
