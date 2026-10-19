# ParMETIS 4.0.3 build decisions

Source: the supplied `parmetis-4.0.3.tar.gz` archive. Its SHA-256 is pinned in
`build-parmetis.sh` and verified before extraction:

```text
f2d9a231b7cf97f1fee6e8c9663113ebf6c240d407d3c118c55b3633d6be6e5f
```

The archive's `BUILD.txt` and `Install.txt` describe its CMake configuration and
installation. The script uses the equivalent CMake options directly, with separate
static/shared build directories. No source downloads are needed.

## Configuration

- Release build with 32-bit indices and 32-bit reals, matching the approved METIS
  configuration and GNU's installed libraries.
- OpenMP, debugging, assertions, and profiling disabled, as for METIS.
- Compile with the matching Intel MPI wrappers, `mpiicx` and `mpiicpx`.
- Generate both `libparmetis.a` and `libparmetis.so`. Every source compilation,
  including the static library and upstream tools, uses `-fPIC`, with CMake PIC
  also enabled. Shared linking uses `--no-undefined`.
- Link against the matching compiler's existing METIS 5.1.0 installation instead
  of rebuilding the bundled copy. Static ParMETIS consumers must also link METIS
  and MPI. The shared library records paths to its matching libraries.

The bundled METIS/GKlib sources, private headers, and public headers were compared
with the supplied METIS 5.1.0 archive: all 106 files under `GKlib/`, `libmetis/`,
and `include/` match exactly. The build verifies the installed METIS configuration,
source checksum, and header before proceeding. The upstream CMake target that
would build METIS is replaced with an imported target for the existing library.
ParMETIS algorithm sources are unchanged.

Each Intel prefix includes upstream programs, `LICENSE.txt`, build instructions,
the adjusted top-level CMake file, compilation databases, and
`share/parmetis/build-config.json`. The configuration records the ABI, compiler,
MPI installation, METIS dependency, PIC settings, and archive checksum.

## GNU reuse and modules

GNU reuses Ubuntu's original ParMETIS 4.0.3/OpenMPI installation, including its
static and shared libraries. No GNU replacement is compiled. Unlike several
other Ubuntu numerical packages, this one installs its libraries under `/usr/lib`,
not the multiarch subdirectory; the generic MPI module handles that layout.
GNU's static ParMETIS archive is tested with the available shared METIS library,
because Ubuntu's METIS package does not provide a static archive.

The module `parmetis/4.0.3` appears only after loading MPI and is a relative link
to `MPI/generic.lua`. Intel prefixes follow:

```text
/opt/intel-<compiler-major>/impi-<mpi-major>/parmetis/4.0.3
```

Load `metis/5.1.0` as well for METIS headers and link paths. GNU package provenance
is recorded in `/usr/local/share/hofem/parmetis/gnu.packages`. Distribution build
settings remain unchanged.

## Validation

`hofem-parmetis-test` runs two MPI ranks for every stack and each library variant.
It checks partition balance, reported global edge cuts, and distributed
nested-dissection ordering as a global permutation. Intel checks additionally
verify the MPI/METIS library paths, absence of an OpenMP runtime, no text relocations,
PIC flags in every compilation command, and that bundled METIS was not rebuilt.
The entire Intel ParMETIS and METIS static archives are also linked into a shared
library to validate their PIC code together. The full HOFEM smoke suite includes
this test.
