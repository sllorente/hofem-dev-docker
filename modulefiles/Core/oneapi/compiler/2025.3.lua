help("This module loads the Intel OneAPI compilers.")
whatis("Configure for use with Intel 64-bit compiler(s).")
family("compiler")
local intel_root="/opt/intel/oneapi"
local target_arch = "intel64"
local target_platform = "linux"

local version = myModuleVersion()
local pkgname = myModuleName():gsub("^oneapi/", "")
local cmplr_root = pathJoin(intel_root, pkgname, version)
local cmplr_root_p = pathJoin(cmplr_root, target_platform)

local pkgV  = version:match('%d+')      -- one digit rule
local pkgVV = version:match('%d+%.%d+')  -- two digit rule
if not pkgV then pkgV = version end
if not pkgVV then pkgVV = pkgV end

-- Setup Modulepath for packages built by this compiler
local mroot = os.getenv("MODULEPATH_ROOT")
local mdir = pathJoin(mroot, "Compiler/intel", pkgV)
prepend_path("MODULEPATH", mdir)

if mode() == "load" then
   LmodMessage("Loading Intel OneAPI " .. pkgname .. " v. " .. version )
end
if mode() == "unload" then
   LmodMessage("Unloading Intel OneAPI " .. pkgname .. " v. " .. version )
end

-- New vars
unsetenv("INTEL_TARGET_ARCH_IA32")
setenv("CMPLR_ROOT", cmplr_root)
setenv("CC", "icx")
setenv("CXX", "icpx")
setenv("FC", "ifx")
setenv("F77", "ifx")

-- Load dependencies
depends_on("tbb")
depends_on("umf")

-- Load optional dependencies 
try_load("mkl")
try_load("oneapi/debugger/" .. version)
try_load("dpl")
try_load("oclfpga")

-- Driver variables
append_path("OCL_ICD_FILENAMES", pathJoin(cmplr_root, "lib/libintelocl.so"))

-- PATH
prepend_path("PATH", pathJoin(cmplr_root, "bin"))

-- MANPATH for dpcpp
append_path("MANPATH", pathJoin(cmplr_root, "share/man"))

-- CPATH
prepend_path("CPATH", pathJoin(cmplr_root, "opt/compiler/include"))

-- LIBRARY_PATH
prepend_path("LIBRARY_PATH", pathJoin(cmplr_root, "lib"))

-- LD_LIBRARY_PATH
prepend_path("LD_LIBRARY_PATH", pathJoin(cmplr_root, "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(cmplr_root, "opt/compiler/lib"))

-- NLSPATH
prepend_path("NLSPATH", pathJoin(cmplr_root, "lib/compiler", "locale/%l_%t/%N"))

-- others
prepend_path("PKG_CONFIG_PATH", pathJoin(cmplr_root, "lib/pkgconfig"))
prepend_path("CMAKE_PREFIX_PATH", cmplr_root)
setenv("CMPLR_ROOT", cmplr_root)
setenv("DIAGUTIL_PATH", pathJoin(cmplr_root, "/etc/compiler/sys_check/sys_check.sh"))

