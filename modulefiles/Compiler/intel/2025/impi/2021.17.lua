local title = "Intel(R) MPI Library"
local desc = title 
local url = "URL: https://www.intel.com/content/www/us/en/developer/tools/oneapi/mpi-library.html"
---------------------------------------------
whatis(title)
whatis(desc)
whatis(url)
prereq("oneapi/compiler")
family("mpi")

---------------------------------------------
local intel_root = "/opt/intel/oneapi" 
local target_arch = "intel64"
local target_platform = "linux"
---------------------------------------------
local pkgname    = myModuleName()
local version    = myModuleVersion()
local pkgnamever = myModuleFullName()
local root = pathJoin(intel_root, "mpi" , version)
---------------------------------------------
local hierA = hierarchyA(pkgnamever,1)
local compiler = hierA[1]
---------------------------------------------
local pkgV  = version:match('%d+')      -- one digit rule
local pkgVV = version:match('%d+%.%d+')  -- two digit rule
if not pkgV then pkgV = version end
if not pkgVV then pkgVV = pkgV end
---------------------------------------------

---------------------------------------------
help("This module loads " .. pkgname .. "library.")
---------------------------------------------

if mode() == "load" then
   LmodMessage("Loading " .. title .. " v. " .. version)
end
if mode() == "unload" then
   LmodMessage("Unloading " .. title .. " v. " .. version)
end

-- Setup Modulepath for packages built by this compiler
local mroot = os.getenv("MODULEPATH_ROOT")
local mdir = pathJoin(mroot, "MPI", compiler, pkgname, pkgV)
prepend_path("MODULEPATH", mdir)
---------------------------------------------


local i_mpi_library_kind=os.getenv("I_MPI_LIBRARY_KIND") or "release"

-- New vars
setenv("I_MPI_ROOT", root)
setenv("MPIROOT", root)
setenv("MPICC", "mpiicx")
setenv("MPICXX", "mpiicpx")
setenv("MPIFC", "mpiifx")

-- PATH
prepend_path("PATH", pathJoin(root, "bin"))

-- CPATH
prepend_path("CPATH", pathJoin(root, "include"))

-- LIBRARY_PATH
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LIBRARY_PATH", pathJoin(root, "lib", i_mpi_library_kind))

-- LD_LIBRARY_PATH
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib", i_mpi_library_kind))

-- CLASSPATH
prepend_path("CLASSPATH", pathJoin(root, "share/java/mpi.jar"))

-- MANPATH
prepend_path("MANPATH", pathJoin(root, "share/man"))

-- PKG_CONFIG_PATH
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))

-- Libfabric
local i_mpi_ofi_library_internal=os.getenv("I_MPI_OFI_LIBRARY_INTERNAL") or "yes"
if i_mpi_ofi_library_internal ~= '0' and
   i_mpi_ofi_library_internal ~= 'no' and
   i_mpi_ofi_library_internal ~= 'off' and
   i_mpi_ofi_library_internal ~= 'disable'
then
   local fabric = pathJoin(root, "opt/mpi/libfabric")
   if not isDir(fabric) then
      fabric = pathJoin(intel_root, "libfabric/latest")
   end
   setenv("FI_PROVIDER_PATH", pathJoin(fabric, "lib/prov"))
   prepend_path("PATH", pathJoin(fabric, "bin"))
   prepend_path("LIBRARY_PATH", pathJoin(fabric, "lib"))
   prepend_path("LD_LIBRARY_PATH", pathJoin(fabric, "lib"))
end

-- Library installation paths, also available before a build is installed.
setenv("GRF_" .. pkgname:upper() .. "ROOT", root)
setenv("GRF_" .. pkgname:upper() .. "INC", pathJoin(root, "include"))
setenv("GRF_" .. pkgname:upper() .. "LIB", pathJoin(root, "lib"))
setenv("GRF_" .. pkgname:upper() .. "BIN", pathJoin(root, "bin"))
setenv("GRF_" .. pkgname:upper() .. "_VERSION", version)
