#!/usr/bin/env python3
"""Install the supplied hierarchy and add modules for installed toolchains."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path("/opt/modulefiles")
SOURCE = Path("/usr/local/share/hofem/modulefiles")
INTEL = Path("/opt/intel/oneapi")


def query(package, field="Version"):
    return subprocess.check_output(
        ["dpkg-query", "-W", "-f=${" + field + "}", package], text=True
    ).strip()


def version(package):
    # Remove epochs and Debian/Ubuntu revision suffixes from module names.
    return re.match(r"\d+(?:\.\d+)*", query(package).split(":")[-1]).group()


def link(relative, template):
    target = ROOT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_symlink() or target.exists():
        target.unlink()
    target.symlink_to(os.path.relpath(ROOT / template, target.parent))


def configure_gnu():
    shutil.copytree(SOURCE, ROOT, dirs_exist_ok=True, symlinks=True)
    compiler = subprocess.check_output(["gfortran", "-dumpfullversion"], text=True).strip()
    compiler_root = f"Compiler/gcc/{compiler.split('.')[0]}"
    mpi = version("libopenmpi-dev")
    mpi_root = f"MPI/gcc/{compiler.split('.')[0]}/openmpi/{mpi.split('.')[0]}"
    link(f"Core/gfortran/{compiler}.lua", "templates/gfortran.lua")
    link(f"{compiler_root}/openmpi/{mpi}.lua", "templates/openmpi.lua")
    serial = {
        "metis": "libmetis-dev", "arpack": "libarpack2-dev",
        "scotch": "libscotch-dev", "openblas": "libopenblas-openmp-dev",
        "lapack": "liblapack-dev",
    }
    parallel = {
        "parmetis": "libparmetis-dev", "parpack": "libparpack2-dev",
        "ptscotch": "libptscotch-dev", "mumps": "libmumps-dev",
        "scalapack": "libscalapack-openmpi-dev",
    }
    for name, package in serial.items():
        link(f"{compiler_root}/{name}/{version(package)}.lua", "Compiler/generic.lua")
    for name, package in parallel.items():
        link(f"{mpi_root}/{name}/{version(package)}.lua", "MPI/generic.lua")
    header = Path("/usr/local/include/gidpost.h").read_text()
    gidpost = ".".join(re.search(r"#define GP_VERSION_" + part + r"\s+(\d+)", header)[1]
                       for part in ("MAJOR", "MINOR"))
    link(f"{compiler_root}/gidpost/{gidpost}.lua", "Compiler/generic.lua")
    (ROOT / "gnu.toolchain").write_text(f"{compiler}\t{mpi}\n")


def configure_intel(compiler, mpi, mkl):
    major = compiler.split(".")[0]
    base = "Compiler/intel/2025"
    target = f"Compiler/intel/{major}"
    # Module contents derive their paths from the requested name and hierarchy.
    for component, release, template in (
        ("compiler", compiler, "2025.3"),
        ("debugger", compiler, "2025.3"),
        ("dev-utilities", compiler, "2021.7.0"),
    ):
        path = f"Core/oneapi/{component}/{release}.lua"
        source = f"Core/oneapi/{component}/{template}.lua"
        if path != source:
            link(path, source)
    tbb = re.search(r"intel-oneapi-tbb-devel-([\d.]+)",
                    query(f"intel-oneapi-dpcpp-cpp-{compiler}", "Depends"))[1]
    umf_series = re.search(r"intel-oneapi-umf-([\d.]+)",
                           query(f"intel-oneapi-compiler-dpcpp-cpp-runtime-{compiler}", "Depends"))[1]
    umf = version(f"intel-oneapi-umf-{umf_series}")
    for name, release, template in (
        ("tbb", tbb, "2022.3"), ("umf", umf, "1.0.2"),
        ("mkl", mkl, "2025.3"), ("impi", mpi, "2021.17"),
    ):
        path, source = f"{target}/{name}/{release}.lua", f"{base}/{name}/{template}.lua"
        if path != source:
            link(path, source)
    (ROOT / f"MPI/intel/{major}/impi/{mpi.split('.')[0]}").mkdir(parents=True, exist_ok=True)


def hide_unavailable():
    # Preserve reference modulefiles/symlinks without advertising absent builds.
    search_roots = [ROOT / "Core", *ROOT.glob("Compiler/intel/*"),
                    *ROOT.glob("MPI/intel/*/impi/*")]
    for search_root in search_roots:
        hidden = []
        for path in sorted(search_root.rglob("*.lua")):
            if path.name.startswith("."):
                continue
            relative = path.relative_to(search_root).with_suffix("")
            parts = path.relative_to(ROOT).parts
            release = path.stem
            if parts[:2] == ("Core", "oneapi"):
                prefix = INTEL / parts[2] / release
            elif parts[:2] == ("Compiler", "intel"):
                name = parts[3]
                if name in ("tbb", "mkl", "umf", "impi"):
                    component = "mpi" if name == "impi" else name
                    series = ".".join(release.split(".")[:2]) if name == "umf" else release
                    prefix = INTEL / component / series
                    if name == "umf" and prefix.exists() and release != version(f"intel-oneapi-umf-{series}"):
                        hidden.append(str(relative))
                        continue
                else:
                    prefix = Path(f"/opt/intel-{parts[2]}") / name / release
            elif parts[:2] == ("MPI", "intel"):
                prefix = Path(f"/opt/intel-{parts[2]}/impi-{parts[4]}") / parts[5] / release
            else:
                continue
            if not prefix.is_dir():
                hidden.append(str(relative))
        (search_root / ".modulerc.lua").write_text(
            "-- Modules for reference builds absent from this image.\n" +
            "".join(f'hide_version("{name}")\n' for name in hidden)
        )


if sys.argv[1] == "gnu":
    configure_gnu()
elif sys.argv[1] == "intel":
    configure_intel(*sys.argv[2:5])
else:
    raise SystemExit("Usage: hofem-configure-modules gnu | intel COMPILER MPI MKL")
hide_unavailable()
