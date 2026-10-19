---------------------------------------------
local intel_root = "/opt/intel/oneapi" 
local target_arch = "intel64"
local target_platform = "linux"
---------------------------------------------
local pkgname    = myModuleName()
local version    = myModuleVersion()
local root = pathJoin(intel_root, pkgname , version)
---------------------------------------------

prereq("oneapi/compiler")
help("This module loads tbb library.")
whatis("Intel(R) oneAPI Threading Building Blocks for " .. target_arch)

if mode() == "load" then
   LmodMessage("Loading " .. pkgname .. " v. " .. version)
end
if mode() == "unload" then
   LmodMessage("Unloading " .. pkgname .. " v. " .. version)
end

-- New vars
setenv("TBBROOT", root)

-- CPATH
prepend_path("CPATH", pathJoin(root, "include"))

-- LIBRARY_PATH
prepend_path("LIBRARY_PATH", pathJoin(root, "lib", target_arch, "gcc4.8"))

-- LD_LIBRARY_PATH
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib", target_arch, "gcc4.8"))

-- CMAKE_PREFIX_PATH
prepend_path("CMAKE_PREFIX_PATH", root)

