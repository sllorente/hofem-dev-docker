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


def remove_library_links(root):
    # Preserve compiler/MPI aliases and all directories and generic modulefiles.
    for path in root.rglob("*.lua"):
        if path.is_symlink() and path.resolve().name == "generic.lua":
            path.unlink()


def configure_gnu():
    shutil.copytree(SOURCE, ROOT, dirs_exist_ok=True, symlinks=True)
    remove_library_links(ROOT)
    remove_library_links(SOURCE)
    compiler = subprocess.check_output(["gfortran", "-dumpfullversion"], text=True).strip()
    compiler_root = f"Compiler/gcc/{compiler.split('.')[0]}"
    mpi = version("libopenmpi-dev")
    mpi_root = f"MPI/gcc/{compiler.split('.')[0]}/openmpi/{mpi.split('.')[0]}"
    link(f"Core/gfortran/{compiler}.lua", "templates/gfortran.lua")
    link(f"{compiler_root}/openmpi/{mpi}.lua", "templates/openmpi.lua")
    (ROOT / mpi_root).mkdir(parents=True, exist_ok=True)
    (ROOT / "gnu.toolchain").write_text(f"{compiler}\t{mpi}\n")


def configure_gidpost():
    # The derived image adds only modules for libraries it actually installs.
    releases = os.environ.get("GIDPOST_VERSIONS", "2.14 2.9").split()
    gnu, _ = (ROOT / "gnu.toolchain").read_text().split()
    majors = {"gcc/" + gnu.split(".")[0]}
    for profile in Path("/usr/local/share/hofem/intel").glob("*.toolchain"):
        compiler, _, _ = profile.read_text().split()
        majors.add("intel/" + compiler.split(".")[0])
    for compiler in sorted(majors):
        for release in releases:
            link(f"Compiler/{compiler}/gidpost/{release}.lua", "Compiler/generic.lua")


def configure_arpack():
    gnu, mpi = (ROOT / "gnu.toolchain").read_text().split()
    major = gnu.split(".")[0]
    link(f"Compiler/gcc/{major}/arpack/97.lua", "Compiler/generic.lua")
    link(f"MPI/gcc/{major}/openmpi/{mpi.split('.')[0]}/parpack/97.lua", "MPI/generic.lua")
    for profile in Path("/usr/local/share/hofem/intel").glob("*.toolchain"):
        compiler, mpi, _ = profile.read_text().split()
        major = compiler.split(".")[0]
        link(f"Compiler/intel/{major}/arpack/97.lua", "Compiler/generic.lua")
        link(f"MPI/intel/{major}/impi/{mpi.split('.')[0]}/parpack/97.lua", "MPI/generic.lua")


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
            if name == "impi":
                link(path, source)
            else:
                # Compiler dependencies remain available without library symlinks.
                destination = ROOT / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                if destination.is_symlink():
                    destination.unlink()
                shutil.copyfile(ROOT / source, destination)
    (ROOT / f"MPI/intel/{major}/impi/{mpi.split('.')[0]}").mkdir(parents=True, exist_ok=True)


def unhide_all():
    # Modules also define installation prefixes before their libraries are built.
    for path in ROOT.rglob(".modulerc.lua"):
        path.unlink()


if sys.argv[1] == "gnu":
    configure_gnu()
elif sys.argv[1] == "gidpost":
    configure_gidpost()
elif sys.argv[1] == "arpack":
    configure_arpack()
elif sys.argv[1] == "intel":
    configure_intel(*sys.argv[2:5])
else:
    raise SystemExit("Usage: hofem-configure-modules gnu | intel COMPILER MPI MKL | gidpost | arpack")
unhide_all()
