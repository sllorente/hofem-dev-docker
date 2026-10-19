#!/bin/bash
set -eo pipefail

profile=${1:?Specify a toolchain profile}
apt-get update

# Query tracking packages for their candidate version without installing them.
latest_series() {
    local candidate
    candidate=$(apt-cache policy "$1" | awk '/Candidate:/ {print $2}')
    if [[ ! $candidate =~ ^([0-9]+\.[0-9]+)\. ]]; then
        printf 'Cannot resolve the latest release of %s: %s\n' "$1" "$candidate" >&2
        return 1
    fi
    printf '%s\n' "${BASH_REMATCH[1]}"
}

compiler=${2:-$(latest_series intel-oneapi-compiler-fortran)}
mpi=${3:-$(latest_series intel-oneapi-mpi-devel)}
mkl=${4:-$(latest_series intel-oneapi-mkl-devel)}

# Payload packages only: no toolkit, C++ compiler wrapper, or MKL metapackages.
# Keep required dependencies; --no-install-recommends omits optional additions.
packages=(
    "intel-oneapi-dpcpp-cpp-${compiler}"
    "intel-oneapi-compiler-fortran-${compiler}"
    "intel-oneapi-mpi-devel-${mpi}"
    "intel-oneapi-mkl-core-devel-${mkl}"
)
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"

mkdir -p /usr/local/share/hofem/intel
for component in "compiler/${compiler}" "mpi/${mpi}" "mkl/${mkl}"; do
    test -f "/opt/intel/oneapi/${component}/env/vars.sh"
done

python3 /usr/local/sbin/hofem-configure-modules intel "$compiler" "$mpi" "$mkl"

# Record exact package versions for inspection and reproducibility.
dpkg-query -W -f='${Package}\t${Version}\n' "${packages[@]}" \
    > "/usr/local/share/hofem/intel/${profile}.packages"
printf '%s\t%s\t%s\n' "$compiler" "$mpi" "$mkl" \
    > "/usr/local/share/hofem/intel/${profile}.toolchain"
rm -rf /var/lib/apt/lists/*
