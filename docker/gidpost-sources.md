# Bundled GiDPost sources

Image builds use `gidpost-2.9.tar.gz` and `gidpost-2.14.tar.gz` from this
folder. The Dockerfile copies them to `/usr/local/share/hofem/sources`, and
`build-gidpost.sh` verifies their SHA-256 hashes before extraction. Missing
archives fail the build; the script never downloads replacement sources.

These are source-only repackagings of the official ZIP releases, not upstream
published tarballs. They contain unchanged upstream files from `CMakeLists.txt`,
`gidpost_config.h.in`, `source/`, `cfortran/`, `fortran_module/`, and `LICENSE`.
Examples, bundled binaries, and previous build directories are omitted.
Compatibility fixes are applied separately by `build-gidpost.sh`.

## Embedded HDF5

`hdf5-1.10.10.tar.gz` is the unchanged official source archive downloaded from:

https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.10/src/hdf5-1.10.10.tar.gz

SHA-256: `a6877ab7bd5d769d2d68618fdb54beb50263dcc2a8c157fe7e2186925cdb02db`.
Image builds use this bundled archive without source downloads.

Ubuntu's HDF5 static archives are not PIC-compatible, so they cannot be embedded
in `libgidpost.so`. `build-gidpost-hdf5.sh` builds private static/shared HDF5 C and
HL libraries with the matching compiler, Release optimization, and `-fPIC`.
Both GiDPost releases share one HDF5 build per compiler stack. MPI,
C++/Fortran bindings, tools, examples, ROS3, and HDFS are disabled; zlib
and SZIP compression remain enabled. This serial HDF5 build is private to GiDPost;
the image's system HDF5 and other libraries are unchanged.

Core thread safety is enabled, matching Ubuntu's HDF5 build. Combining it with
HL requires upstream's `ALLOW_UNSUPPORTED=ON` option. This preserves the core
locking configuration; it does not establish thread safety for the HL layer or
GiDPost's own state.

`embed-gidpost-hdf5.sh` combines the original GiDPost archive, HDF5 HL, and HDF5
core into one relocatable object, localizes HDF5 definitions, and produces the
combined `libgidpost.a` and `libgidpost.so`. It preserves GiDPost's public symbols
and its existing Fortran interfaces. GNU's existing GiDPost objects are reused
without recompilation. The original archive is retained in
`share/gidpost/libgidpost-unbundled.a` for idempotent relinking.

Neither GiDPost variant requires separate HDF5 link flags. Static clients still
need `-lsz -lz -ldl -lpthread -lm`; these dependencies remain external. The shared
library records them automatically. Embedded HDF5 symbols are private, avoiding
collisions with an application's independent HDF5 library. HDF5 loadable filter
plugins that expect globally exported HDF5 symbols are outside this configuration;
the built-in zlib/SZIP filters remain available.

Private HDF5 installations live under
`/opt/<compiler>-<major>/gidpost-hdf5/1.10.10`, outside `LD_LIBRARY_PATH` and the
module hierarchy. They retain static/shared libraries, headers, the license,
compilation commands, and build settings. Each GiDPost prefix records provenance
in `share/gidpost/embedded-hdf5.json` and includes the HDF5 license.

`hofem-gidpost-hdf5-test` checks both releases on all stacks: C/Fortran clients
link without HDF5 flags, write files readable by the system HDF5, retain GiDPost
exports, and have no unresolved HDF5 symbols, dynamic HDF5 dependencies, or text
relocations. A whole-archive shared link validates the combined static archive.
These are focused integration checks, not the complete upstream HDF5 test suite.

## Official release archives

- 2.9: https://downloads.gidsimulation.com/Tools/gidpost/old/gidpost-2.9.zip
  SHA-256: `88d6edd68892dba3d2ada6d62b46cf45b79e961828b83d383e5d38464c683e8a`
- 2.14: https://downloads.gidsimulation.com/Tools/gidpost/gidpost-2.14.zip
  SHA-256: `43a3d907558503b3248abe6d61e39f1d45430ac98573489af25cbff5e8e82f37`

## Bundled tarballs

- `gidpost-2.9.tar.gz`:
  `edfdde3a84eda7923f7713a7e2cbab7bce2cc3d740587aef90514562c4993eb5`
- `gidpost-2.14.tar.gz`:
  `d518bb622d9a8501e5ab7bf1f4dc4092db80f1e8cabe30ba177811d77d85e7bc`

For deterministic repackaging, sort file paths, preserve file bytes, set tar
ownership and timestamps to zero and file permissions to `0644`, and use a gzip
header with timestamp zero and no filename. Each archive has a single top-level
`gidpost-<version>/` directory. Include the upstream license in every repackaging.
