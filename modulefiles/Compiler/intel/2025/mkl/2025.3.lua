local title = "Intel(R) oneAPI Math Kernel Library (oneMKL) IA-64 architecture"
local desc = title 
local url = "URL: https://www.intel.com/content/www/us/en/developer/tools/oneapi/onemkl.html"
---------------------------------------------
whatis(title)
whatis(desc)
whatis(url)
prereq("oneapi/compiler")
depends_on("tbb")

---------------------------------------------
local intel_root = "/opt/intel/oneapi" 
local target_arch = "intel64"
local target_platform = "linux"
---------------------------------------------
local pkgname    = myModuleName()
local version    = myModuleVersion()
local pkgV  = version:match('%d+')      -- one digit rule
local pkgVV = version:match('%d+%.%d+')  -- two digit rule
if not pkgV then pkgV = version end
if not pkgVV then pkgVV = pkgV end
local root = pathJoin(intel_root, pkgname , version)
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

-- New vars
setenv("MKLROOT", root)

-- CPATH
prepend_path("CPATH", pathJoin(root, "include"))

-- LIBRARY_PATH
prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))

-- LD_LIBRARY_PATH
prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))

-- PKG_CONFIG_PATH
prepend_path("PKG_CONFIG_PATH", pathJoin(root, "lib/pkgconfig"))

-- NLSPATH
prepend_path("NLSPATH",pathJoin(root, "share", "locale/%l_%t/%N"))

-- others
prepend_path("CMAKE_PREFIX_PATH", pathJoin(root, "lib/cmake"))


-- Library installation paths, also available before a build is installed.
setenv("GRF_" .. pkgname:upper() .. "ROOT", root)
setenv("GRF_" .. pkgname:upper() .. "INC", pathJoin(root, "include"))
setenv("GRF_" .. pkgname:upper() .. "LIB", pathJoin(root, "lib"))
setenv("GRF_" .. pkgname:upper() .. "BIN", pathJoin(root, "bin"))
setenv("GRF_" .. pkgname:upper() .. "_VERSION", version)
