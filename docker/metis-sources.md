# METIS 5.1.0 build decisions

Source: the supplied `metis-5.1.0.tar.gz` archive, bundled in this directory.
The build verifies its SHA-256 before extraction:

```text
76faebe03f6c963127dbb73c13eab58c9a3faeae48779f049066a21c087c5db2
```

No source download is required. `BUILD.txt` and `Install.txt` in the archive
provide the upstream instructions. Their `make config` wrapper invokes CMake;
our script uses the equivalent CMake options in separate build directories to
preserve both library variants.

## Approved configuration

| Decision | Setting | Reason |
| --- | --- | --- |
| Graph indices (`IDXTYPEWIDTH`) | 32 bits | Upstream default; matches GNU's installed METIS ABI. |
| Real values (`REALTYPEWIDTH`) | 32 bits | Upstream default; matches GNU's installed METIS ABI. |
| OpenMP | Disabled | Upstream default; avoids an additional OpenMP runtime dependency. |
| Build type | Release | Optimized development environment libraries. |
| Debugging, assertions, profiling | Disabled | Retain upstream defaults for the optimized build. |
| Library variants | Static and shared | Provide both `libmetis.a` and `libmetis.so`. |
| Position-independent code | Enabled for both variants | Every C/C++ compilation uses `-fPIC`; CMake PIC is also enabled. |
| Compiler | Matching Intel `icx`/`icpx` | Separate installations for the two Intel compiler stacks. |
| MPI | Not used | METIS is a serial library; its modules belong in the compiler hierarchy. |

The selected type widths are checked against `include/metis.h` before building.
Callers must use that header's `idx_t` and `real_t` types. Changing either width
changes the interface and requires matching callers.

Both Intel installations include the upstream command-line tools, such as
`gpmetis`, and the bundled GKlib code. No METIS source patches are applied.
Compiler warnings from upstream GKlib's PDB parser and METIS's floating-point
`abs` use remain visible; those code paths are not exhaustively validated.

## GNU reuse

The GNU stack reuses Ubuntu's METIS 5.1.0 installation without recompiling it.
Its header also specifies 32-bit indices and 32-bit reals. The current Ubuntu
package provides a shared library but no static archive. This is retained under
the repository's GNU reuse rule; the static/shared generation requirement applies
to the source-built Intel libraries. Distribution compiler settings are unchanged.
The exact package version is recorded in `/usr/local/share/hofem/metis/gnu.packages`.

## Modules, provenance, and tests

Load `metis/5.1.0` after selecting a compiler. Modules are relative symlinks to
`Compiler/generic.lua`. GNU paths point to `/usr`; Intel installations use
`/opt/intel-<compiler-major>/metis/5.1.0`.

Each Intel prefix contains `share/metis/build-config.json`, the static/shared
compilation databases, upstream instructions, and `LICENSE.txt`.

`hofem-metis-test` checks graph partitioning, balance, reported edge cuts, and
nested-dissection permutation inverses. It tests GNU's shared library and both
Intel library variants. It also links each entire Intel static archive into a
shared library, checks for text relocations, verifies `-fPIC` in every compilation
command, checks the selected ABI and absence of an OpenMP runtime, and exercises
`gpmetis -help`. The complete HOFEM smoke suite invokes this test.
