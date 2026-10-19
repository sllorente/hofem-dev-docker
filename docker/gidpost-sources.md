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
