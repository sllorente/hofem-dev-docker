#!/bin/bash
set -eo pipefail
# This script runs only in a new build layer, never on the host filesystem.
# Remove old GiDPost installations while retaining the installed compiler stacks.
rm -rf /opt/intel-*/gidpost /opt/gcc-*/gidpost \
    /usr/local/src/gidpost-* /usr/local/share/gidpost \
    /usr/local/share/licenses/gidpost /usr/local/share/hofem/gidpost
find /usr/local/lib /usr/local/include -maxdepth 1 -name '*gidpost*' -delete
if [[ -d /usr/local/share/hofem/sources ]]; then
    find /usr/local/share/hofem/sources -maxdepth 1 -name 'gidpost-*' -delete
fi
rm -f /usr/local/sbin/hofem-build-gidpost /usr/local/bin/hofem-smoke-test
rm -rf /opt/modulefiles
python3 /usr/local/sbin/hofem-configure-modules gnu
for profile in /usr/local/share/hofem/intel/*.toolchain; do
    read -r compiler mpi mkl < "$profile"
    python3 /usr/local/sbin/hofem-configure-modules intel "$compiler" "$mpi" "$mkl"
done
test -f /usr/local/share/hofem/intel/2025.3.toolchain
test -f /usr/local/share/hofem/intel/latest.toolchain
touch /usr/local/share/hofem/three-stacks
ldconfig
