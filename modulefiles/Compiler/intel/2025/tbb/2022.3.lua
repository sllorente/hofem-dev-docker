local title = "Intel(R) oneAPI Threading Building Block"
local desc = "Flexible threading library for adding parallelism to complex applications across accelerated architectures." 
local url = "URL: https://www.intel.com/content/www/us/en/developer/tools/oneapi/onetbb.html"
---------------------------------------------
whatis(title)
whatis(desc)
whatis(url)
prereq("oneapi/compiler")

---------------------------------------------
local intel_root = "/opt/intel/oneapi" 
local target_arch = "intel64"
local target_platform = "linux"
---------------------------------------------
local pkgname    = myModuleName()
local version    = myModuleVersion()
if not pkgV then pkgV = version end
if not pkgVV then pkgVV = pkgV end
local root = pathJoin(intel_root, pkgname , version)
local lib = pathJoin(root, "lib")
if isDir(pathJoin(lib, target_arch, "gcc4.8")) then
   lib = pathJoin(lib, target_arch, "gcc4.8")
end
---------------------------------------------

---------------------------------------------
help("This module loads " .. title .. "library.")
---------------------------------------------

if mode() == "load" then
   LmodMessage("Loading " .. title .. " v. " .. version)
end
if mode() == "unload" then
   LmodMessage("Unloading " .. pkgname .. " v. " .. version)
end

-- New vars
setenv("TBBROOT", root)

-- CPATH
prepend_path("CPATH", pathJoin(root, "include"))

-- LIBRARY_PATH
prepend_path("LIBRARY_PATH", lib)

-- LD_LIBRARY_PATH
prepend_path("LD_LIBRARY_PATH", lib)

-- CMAKE_PREFIX_PATH
prepend_path("CMAKE_PREFIX_PATH", root)


-- Library installation paths, also available before a build is installed.
setenv("GRF_" .. pkgname:upper() .. "ROOT", root)
setenv("GRF_" .. pkgname:upper() .. "INC", pathJoin(root, "include"))
setenv("GRF_" .. pkgname:upper() .. "LIB", lib)
setenv("GRF_" .. pkgname:upper() .. "BIN", pathJoin(root, "bin"))
setenv("GRF_" .. pkgname:upper() .. "_VERSION", version)
